import SwiftUI
import TimePriceCore

struct WageEditorView: View {
    var onSaved: (() -> Void)?
    @Environment(AppModel.self) private var model
    @State private var source: WageSource = .direct
    @State private var currency = "USD"
    @State private var hourly = ""
    @State private var gross = ""
    @State private var taxPercent = ""
    @State private var expenses = ""
    @State private var hours = "2080"
    @State private var message: String?

    var body: some View {
        PaperPage(title: "Wage") {
            Text("Use the money you keep, after tax and the costs of doing the work.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.78))
            Picker("Wage source", selection: $source) {
                Text("Hourly").tag(WageSource.direct)
                Text("From annual pay").tag(WageSource.derived)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Wage source")

            Picker("Currency", selection: $currency) {
                Text("USD").tag("USD")
                Text("EUR").tag("EUR")
                Text("GBP").tag("GBP")
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Currency")

            if source == .direct {
                field("Net hourly wage", text: $hourly)
            } else {
                field("Annual gross", text: $gross)
                field("Tax rate (%)", text: $taxPercent)
                field("Annual work expenses", text: $expenses)
                field("Annual hours", text: $hours)
                Text("Net hourly = (annual gross × (1 − tax rate) − expenses) ÷ hours. Hours start at 2,080.")
                    .font(.footnote)
                    .foregroundStyle(TimePriceColor.ink.opacity(0.72))
                if let preview = derivedPreview {
                    Text(preview)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(TimePriceColor.ink)
                        .accessibilityLabel(preview)
                }
            }

            if let message {
                Text(message)
                    .foregroundStyle(TimePriceColor.ink)
                    .accessibilityLabel(message)
            }

            Button("Save wage") { save() }
                .buttonStyle(PineButtonStyle())
                .accessibilityHint("Saves this wage on this device.")
        }
        .onAppear(perform: load)
    }

    private var derivedPreview: String? {
        guard let input = derivedInput() else { return nil }
        do {
            let breakdown = try WageDerivation.derive(input)
            return "\(breakdown.netHourly.plainString(scale: 4)) \(currency) / hour"
        } catch let error as WageError {
            return error.message
        } catch {
            return nil
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TimePriceColor.ink)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(TimePriceColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .accessibilityLabel(title)
        }
    }

    private func load() {
        let inputs = model.profileInputs()
        source = inputs.activeSource
        currency = inputs.currencyCode
        hourly = inputs.directNetHourly?.plainString(scale: 4) ?? ""
        gross = inputs.annualGross?.plainString(scale: 2) ?? ""
        if let tax = inputs.taxRate {
            taxPercent = (tax * 100).plainString(scale: 2)
        }
        expenses = inputs.annualWorkExpenses?.plainString(scale: 2) ?? ""
        hours = inputs.annualHours.plainString(scale: 0)
    }

    private func derivedInput() -> DerivedWageInput? {
        guard
            let grossValue = DecimalMath.parseUserNumber(gross),
            let percent = DecimalMath.parseUserNumber(taxPercent),
            let expenseValue = DecimalMath.parseUserNumber(expenses)
        else { return nil }
        let hourValue = DecimalMath.parseUserNumber(hours) ?? WageDerivation.defaultAnnualHours
        return DerivedWageInput(
            annualGross: grossValue,
            taxRate: percent / 100,
            annualWorkExpenses: expenseValue,
            annualHours: hourValue
        )
    }

    private func save() {
        var inputs = model.profileInputs()
        do {
            if source == .direct {
                guard let value = DecimalMath.parseUserNumber(hourly) else {
                    message = "Enter a net hourly wage."
                    return
                }
                inputs = try inputs.updatingDirect(netHourly: value, currencyCode: currency)
            } else {
                guard let derived = derivedInput() else {
                    message = WageError.missingDerivedInputs.message
                    return
                }
                inputs = try inputs.updatingDerived(derived, currencyCode: currency)
            }
            model.saveWage(inputs, finishOnboarding: false)
            message = model.resolvedWageText()
            onSaved?()
        } catch let error as WageError {
            message = error.message
        } catch {
            message = error.localizedDescription
        }
    }
}

#Preview {
    WageEditorView()
        .timePricePreview()
}

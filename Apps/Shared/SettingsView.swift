import SwiftUI
import TimePriceCore
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showingImporter = false
    @State private var csvText = ""
    @State private var importMessage: String?

    var body: some View {
        PaperPage(title: "Settings") {
            NavigationLink("Edit wage") { WageEditorView() }
                .font(.body.weight(.semibold))
                .foregroundStyle(TimePriceColor.pine)
                .accessibilityHint("Opens the hourly wage or the annual pay form.")

            NavigationLink("Shields") { ShieldsView() }
                .font(.body.weight(.semibold))
                .foregroundStyle(TimePriceColor.pine)

            VStack(alignment: .leading, spacing: 8) {
                Text("Currency")
                    .font(.headline)
                    .foregroundStyle(TimePriceColor.ink)
                Picker("Currency", selection: currencyBinding) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Currency")
                Text("Changing the currency labels the wage. It does not convert money.")
                    .font(.footnote)
                    .foregroundStyle(TimePriceColor.ink.opacity(0.7))
            }

            stepper
            unlockPicker

            Toggle(isOn: annotationBinding) {
                Text("Show hours in Safari")
            }
            .tint(TimePriceColor.pine)
            .accessibilityHint("Turns price annotation on or off. Each site can also be turned off in the Safari popup.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Import a time log")
                    .font(.headline)
                    .foregroundStyle(TimePriceColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Paste CSV or choose a file. Use started_at,ended_at in ISO8601, or date,duration_minutes. Empty rows are ignored. The same start and end are kept once. This does not connect to Toggl.")
                    .font(.footnote)
                    .foregroundStyle(TimePriceColor.ink.opacity(0.75))
                TextField("CSV", text: $csvText, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(TimePriceColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("CSV text")
                Button("Import pasted CSV") {
                    importMessage = model.importCSV(csvText)
                }
                .buttonStyle(QuietButtonStyle())
                Button("Choose CSV file") { showingImporter = true }
                    .buttonStyle(QuietButtonStyle())
                if let importMessage {
                    Text(importMessage)
                        .foregroundStyle(TimePriceColor.ink)
                        .accessibilityLabel(importMessage)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy")
                    .font(.headline)
                    .foregroundStyle(TimePriceColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("TimePrice stays on this device. There is no account, no analytics, and no ads.")
                    .foregroundStyle(TimePriceColor.ink.opacity(0.8))
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    importMessage = model.importCSV(text)
                } catch {
                    importMessage = "TimePrice could not read that file."
                }
            case .failure:
                importMessage = "TimePrice could not open that file."
            }
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { model.profileInputs().currencyCode },
            set: { model.setCurrency($0) }
        )
    }

    private var annotationBinding: Binding<Bool> {
        Binding(
            get: { model.annotationEnabled },
            set: { model.setAnnotationEnabled($0) }
        )
    }

    private var stepper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus length")
                .font(.headline)
                .foregroundStyle(TimePriceColor.ink)
            Stepper(value: focusBinding, in: 15...60) {
                Text("\(model.requiredFocusMinutes) minutes")
            }
            .accessibilityLabel("Focus length, \(model.requiredFocusMinutes) minutes")
        }
    }

    private var focusBinding: Binding<Int> {
        Binding(
            get: { model.requiredFocusMinutes },
            set: { model.setRequiredFocusMinutes($0) }
        )
    }

    private var unlockPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlock window")
                .font(.headline)
                .foregroundStyle(TimePriceColor.ink)
            Picker("Unlock window", selection: unlockBinding) {
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("60 minutes").tag(60)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Unlock window")
            Text("15 minutes is the shortest interval Screen Time can schedule.")
                .font(.footnote)
                .foregroundStyle(TimePriceColor.ink.opacity(0.7))
        }
    }

    private var unlockBinding: Binding<Int> {
        Binding(
            get: { model.unlockWindowMinutes },
            set: { model.setUnlockWindow($0) }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .timePricePreview()
}

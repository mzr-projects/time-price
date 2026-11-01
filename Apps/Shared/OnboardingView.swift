import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0

    var body: some View {
        Group {
            switch step {
            case 0:
                WageEditorView { step = 1 }
            case 1:
                safariStep
            default:
                shieldStep
            }
        }
    }

    private var safariStep: some View {
        PaperPage(title: "Safari") {
            Text("Safari can show a price as hours of deep work. The original price stays on the page.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.78))
            instruction("1", "Open the Settings app, then Safari.")
            instruction("2", "Choose Extensions.")
            instruction("3", "Turn on TimePrice and allow the sites you want.")
            Text("This screen cannot turn the extension on. Safari asks you itself.")
                .font(.footnote)
                .foregroundStyle(TimePriceColor.ink.opacity(0.72))
            Button("Continue") { step = 2 }
                .buttonStyle(PineButtonStyle())
                .accessibilityHint("Goes to the next setup step.")
        }
    }

    private var shieldStep: some View {
        PaperPage(title: "Before an impulse") {
            #if os(iOS)
            Text("Pick apps that should wait until a focus session is finished. You can skip this and choose them later.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.78))
            IOSShieldsScreen()
            #else
            Text("Mac does not shield apps. Family Controls authorization fails in the Mac sandbox, so TimePrice does not ask for it here.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.78))
            Text("A price in Safari becomes hours of deep work. A wishlist link opens after you finish a focus session.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.78))
            #endif
            Button("Start using TimePrice") {
                model.finishOnboarding()
                Task { await NotificationBridge.requestPermission() }
            }
            .buttonStyle(PineButtonStyle())
            .accessibilityHint("Saves setup on this device and opens Home.")
        }
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundStyle(TimePriceColor.pine)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(TimePriceColor.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView()
        .timePricePreview()
}

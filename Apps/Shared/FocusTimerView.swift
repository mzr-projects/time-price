import SwiftUI
import TimePriceCore

struct FocusTimerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            timer(at: context.date)
        }
    }

    private func timer(at date: Date) -> some View {
        let remaining = model.remainingSeconds(at: date)
        let spoken = DurationText.format(totalSeconds: remaining)
        return PaperPage(title: "Focus") {
            Text(phaseTitle)
                .font(.title3)
                .foregroundStyle(TimePriceColor.ink.opacity(0.75))
            NumeralText(text: ClockText.string(seconds: remaining), accessibilityLabel: "\(spoken) remaining")
                .accessibilityAddTraits(.updatesFrequently)
            Text("\(model.requiredFocusMinutes) minutes of deep work. There is no skip.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.72))
            controls
            if model.focusPhase == .completed, let grant = model.activeGrant(at: date) {
                Text("\(grant.windowMinutes) minutes are open. Wishlist links work until then.")
                    .foregroundStyle(TimePriceColor.ink)
                #if os(iOS)
                Text("Shielded apps open during the same window.")
                    .foregroundStyle(TimePriceColor.ink.opacity(0.75))
                #endif
            }
        }
    }

    private var phaseTitle: String {
        switch model.focusPhase {
        case .idle: return "Ready when you are."
        case .running: return "In progress."
        case .paused: return "Paused."
        case .completed: return "The session is finished."
        case .failed: return "This session stopped. Start again when you want."
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.focusPhase {
        case .idle, .completed, .failed:
            Button("Start focus") { model.startOrResume() }
                .buttonStyle(PineButtonStyle())
                .accessibilityHint("Starts a focus session for the length in Settings.")
        case .running:
            Button("Pause") { model.pause() }
                .buttonStyle(QuietButtonStyle())
                .accessibilityHint("Pauses the session. Time stays where it is.")
        case .paused:
            Button("Resume") { model.resume() }
                .buttonStyle(PineButtonStyle())
                .accessibilityHint("Continues the same session.")
        }
    }
}

#Preview {
    FocusTimerView()
        .timePricePreview()
}

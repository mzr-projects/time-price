import FamilyControls
import SwiftUI
import TimePriceCore

struct IOSShieldsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var selection = FamilyActivitySelection()
    @State private var pickerPresented = false
    @State private var status = "Screen Time access has not been asked for yet."
    @State private var scheduleNote: String?
    @State private var groupAvailable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(status)
                .foregroundStyle(TimePriceColor.ink)
                .accessibilityLabel("Screen Time status. \(status)")

            Button("Allow Screen Time access") {
                Task { await requestAccess() }
            }
            .buttonStyle(PineButtonStyle())
            .accessibilityHint("Asks the system for Screen Time access for this device.")

            Button("Choose apps") {
                pickerPresented = true
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityHint("Opens the system picker for apps, categories, and websites.")

            Text(selectionSummary)
                .font(.subheadline)
                .foregroundStyle(TimePriceColor.ink.opacity(0.8))
                .accessibilityLabel(selectionSummary)

            if !groupAvailable {
                Text("The shared App Group is not available until the capability is added. Choices stay on this screen until then.")
                    .font(.footnote)
                    .foregroundStyle(TimePriceColor.ink.opacity(0.75))
            }

            unlockWindow

            if let scheduleNote {
                Text(scheduleNote)
                    .font(.footnote)
                    .foregroundStyle(TimePriceColor.ink.opacity(0.75))
            }

            Text("A finished focus session lifts these shields for the unlock window. When that window ends, the shields come back.")
                .font(.footnote)
                .foregroundStyle(TimePriceColor.ink.opacity(0.75))
        }
        .familyActivityPicker(isPresented: $pickerPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            groupAvailable = SelectionArchive.save(newValue)
            if let controller = model.screenTime as? IOSScreenTimeController {
                controller.restoreShieldsIfNeeded()
            }
        }
        .onAppear(perform: reload)
    }

    private var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        return "\(apps) apps, \(categories) categories, \(sites) websites."
    }

    private var unlockWindow: some View {
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

    private func reload() {
        if let saved = SelectionArchive.load() {
            selection = saved
        }
        groupAvailable = UserDefaults(suiteName: SharedConfig.appGroupID) != nil
        if let controller = model.screenTime as? IOSScreenTimeController {
            status = controller.statusText
            scheduleNote = controller.scheduleNote
        }
    }

    private func requestAccess() async {
        guard let controller = model.screenTime as? IOSScreenTimeController else { return }
        do {
            try await controller.requestAuthorization()
            status = controller.statusText
            controller.restoreShieldsIfNeeded()
            scheduleNote = controller.scheduleNote
        } catch {
            status = "Screen Time access was not granted."
        }
    }
}

#Preview {
    PaperPage(title: "Shields") {
        IOSShieldsScreen()
    }
    .timePricePreview()
}

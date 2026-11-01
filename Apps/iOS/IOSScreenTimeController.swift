import DeviceActivity
import FamilyControls
import Foundation
import TimePriceCore

/// Screen Time shields. iOS only. The Mac target does not compile this file.
@MainActor
final class IOSScreenTimeController: ScreenTimeControlling {
    private let activityName = DeviceActivityName(rawValue: "timeprice.unlock")
    private let center = DeviceActivityCenter()
    private(set) var scheduleNote: String?

    var statusText: String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            return "Screen Time access has not been asked for yet."
        case .denied:
            return "Screen Time access is off. TimePrice cannot shield apps until it is allowed."
        case .approved:
            return "Screen Time access is on."
        @unknown default:
            return "Screen Time access is unavailable."
        }
    }

    func requestAuthorization() async throws {
        // Development on the author's devices works after the Family Controls capability
        // is added. App Store and TestFlight distribution require Apple's separate
        // Family Controls distribution entitlement:
        // https://developer.apple.com/contact/request/family-controls-distribution
        // This call does not treat that entitlement as already granted.
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func restoreShieldsIfNeeded() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        ShieldApplier.reapplyFromSharedState()
    }

    func unlockForActiveGrant() {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            scheduleNote = "Screen Time access is not on, so shields were not changed."
            return
        }
        ShieldApplier.clear()
        scheduleNote = scheduleUnlockInterval()
    }

    /// DeviceActivitySchedule intervals must be at least 15 minutes.
    /// The end is moved out to that floor when a grant would otherwise be shorter.
    private func scheduleUnlockInterval() -> String? {
        let now = Date()
        let grantEnd = SharedConfigStore.appGroupStore()?.readGrant()?.end
        let minimumEnd = now.addingTimeInterval(15 * 60)
        let end = max(grantEnd ?? minimumEnd, minimumEnd)
        let calendar = Calendar.current
        let units: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(units, from: now),
            intervalEnd: calendar.dateComponents(units, from: end),
            repeats: false
        )
        center.stopMonitoring([activityName])
        do {
            try center.startMonitoring(activityName, during: schedule)
            return nil
        } catch {
            return "Screen Time did not accept the unlock schedule. If the monitor is late, TimePrice puts the shields back the next time it opens."
        }
    }
}

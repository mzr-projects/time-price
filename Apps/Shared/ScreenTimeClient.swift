import Foundation

/// Screen Time is iPhone-only. The Mac app uses this no-op and never calls Family Controls.
@MainActor
protocol ScreenTimeControlling: AnyObject {
    func restoreShieldsIfNeeded()
    func unlockForActiveGrant()
    var statusText: String { get }
}

@MainActor
final class NoopScreenTime: ScreenTimeControlling {
    func restoreShieldsIfNeeded() {}
    func unlockForActiveGrant() {}
    var statusText: String {
        "Screen Time shields are an iPhone feature."
    }
}

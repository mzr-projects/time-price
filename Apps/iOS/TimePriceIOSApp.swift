import SwiftUI
import TimePriceCore

@main
struct TimePriceIOSApp: App {
    @State private var model: AppModel
    private let notifications = NotificationBridge()

    init() {
        let screenTime = IOSScreenTimeController()
        let model = AppModel(screenTime: screenTime)
        _model = State(initialValue: model)
        notifications.configure()
        notifications.onFocusRequest = {
            model.handleIncomingFocus()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { url in
                    model.handle(url: url)
                }
        }
    }
}

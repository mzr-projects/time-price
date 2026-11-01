import SwiftUI

@main
struct TimePriceMacApp: App {
    @State private var model: AppModel
    private let notifications = NotificationBridge()

    init() {
        let model = AppModel()
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
                .frame(minWidth: 720, minHeight: 520)
                .onOpenURL { url in
                    model.handle(url: url)
                }
        }
        .defaultSize(width: 880, height: 640)
    }
}

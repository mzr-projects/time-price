import Foundation
import TimePriceCore
import UserNotifications

/// The shield cannot open the host app. It records a flag and posts a notification whose tap uses timeprice://focus.
enum FocusHandoff {
    static let notificationID = "timeprice.wants-focus"

    static func requestFocus() {
        SharedConfigStore.appGroupStore()?.setWantsFocus(true)
        let content = UNMutableNotificationContent()
        content.title = "Start focus"
        content.body = "Open TimePrice to begin a focus session."
        content.sound = .default
        content.userInfo = ["openURL": "timeprice://focus"]
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

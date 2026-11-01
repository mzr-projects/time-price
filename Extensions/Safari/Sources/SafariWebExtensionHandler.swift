import Foundation
import SafariServices
import TimePriceCore

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]
        let response = reply(to: message)
        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: response]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func reply(to message: [String: Any]?) -> [String: Any] {
        guard message?["type"] as? String == "getConfig" else {
            return [:]
        }
        let snapshot = SharedConfigStore.appGroupStore()?.read() ?? .empty
        return [
            "netHourly": snapshot.netHourly,
            "currencyCode": snapshot.currencyCode,
            "enabled": snapshot.enabled,
            "requiredFocusMinutes": snapshot.requiredFocusMinutes,
            "unlockWindowMinutes": snapshot.unlockWindowMinutes,
        ]
    }
}

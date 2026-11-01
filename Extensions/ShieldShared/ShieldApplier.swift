import FamilyControls
import Foundation
import ManagedSettings
import TimePriceCore

enum ShieldStore {
    static let name = ManagedSettingsStore.Name(rawValue: "timeprice")
}

/// Sets and clears only the shield fields TimePrice owns.
enum ShieldApplier {
    static func apply(_ selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore(named: ShieldStore.name)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    static func clear() {
        let store = ManagedSettingsStore(named: ShieldStore.name)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    /// An unexpired grant lifts shields. A missing or expired grant puts them back.
    static func reapplyFromSharedState(now: Date = Date()) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        if let grant = SharedConfigStore.appGroupStore()?.readGrant(),
           now >= grant.start && now < grant.end {
            clear()
            return
        }
        if let selection = SelectionArchive.load() {
            apply(selection)
        } else {
            clear()
        }
    }
}

import FamilyControls
import Foundation
import TimePriceCore

enum SelectionArchive {
    @discardableResult
    static func save(_ selection: FamilyActivitySelection) -> Bool {
        guard let defaults = UserDefaults(suiteName: SharedConfig.appGroupID) else { return false }
        guard let data = try? JSONEncoder().encode(selection) else { return false }
        defaults.set(data, forKey: SharedConfig.familyActivitySelection)
        return true
    }

    static func load() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: SharedConfig.appGroupID) else { return nil }
        guard let data = defaults.data(forKey: SharedConfig.familyActivitySelection) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}

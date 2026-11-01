import ManagedSettings
import ManagedSettingsUI
import TimePriceCore
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let minutes = SharedConfigStore.appGroupStore()?.read().requiredFocusMinutes ?? FocusEngine.defaultMinutes
        let subtitle = "Finish \(minutes) minutes of deep work to open it."
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: Self.paper,
            icon: UIImage(named: "ShieldIcon"),
            title: ShieldConfiguration.Label(text: "This app waits on focus", color: Self.ink),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: Self.ink),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start focus", color: Self.cream),
            primaryButtonBackgroundColor: Self.pine,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Not now", color: Self.pine)
        )
    }

    private static let paper = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.110, green: 0.098, blue: 0.082, alpha: 1)
        }
        return UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1)
    }

    private static let ink = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1)
        }
        return UIColor(red: 0.110, green: 0.098, blue: 0.082, alpha: 1)
    }

    private static let cream = UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1)

    private static let pine = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.490, green: 0.812, blue: 0.714, alpha: 1)
        }
        return UIColor(red: 0.122, green: 0.435, blue: 0.357, alpha: 1)
    }
}

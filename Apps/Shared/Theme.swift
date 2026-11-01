import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum TimePriceColor {
    static let paper = Color.adaptive(light: (0.965, 0.945, 0.910), dark: (0.110, 0.098, 0.082))
    static let card = Color.adaptive(light: (1.0, 0.988, 0.973), dark: (0.176, 0.157, 0.137))
    static let ink = Color.adaptive(light: (0.110, 0.098, 0.082), dark: (0.965, 0.945, 0.910))
    static let secondaryInk = Color.adaptive(light: (0.110, 0.098, 0.082), dark: (0.965, 0.945, 0.910))
    static let pine = Color.adaptive(light: (0.122, 0.435, 0.357), dark: (0.490, 0.812, 0.714))
    static let onPine = Color.adaptive(light: (0.965, 0.945, 0.910), dark: (0.110, 0.098, 0.082))
    static let line = Color.adaptive(light: (0.110, 0.098, 0.082), dark: (0.965, 0.945, 0.910))
}

extension Color {
    /// Light and dark pairs so paper and ink stay readable when the system appearance changes.
    static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        #if canImport(UIKit)
        let dynamic = UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
        return Color(uiColor: dynamic)
        #elseif canImport(AppKit)
        let dynamic = NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            let rgb = match == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
        return Color(nsColor: dynamic)
        #else
        return Color(red: light.0, green: light.1, blue: light.2)
        #endif
    }
}

struct PineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(TimePriceColor.onPine)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(TimePriceColor.pine.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(TimePriceColor.pine)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(TimePriceColor.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TimePriceColor.pine.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PaperPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.largeTitle.weight(.medium))
                    .foregroundStyle(TimePriceColor.ink)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(TimePriceColor.paper.ignoresSafeArea())
    }
}

struct NumeralText: View {
    let text: String
    var accessibilityLabel: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 52

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(TimePriceColor.ink)
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .accessibilityLabel(accessibilityLabel)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TimePriceColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

enum ClockText {
    static func string(seconds: Int) -> String {
        let safe = max(0, seconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

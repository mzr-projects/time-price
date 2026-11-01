import SwiftUI

struct ShieldsView: View {
    var body: some View {
        #if os(iOS)
        PaperPage(title: "Shields") {
            IOSShieldsScreen()
        }
        #else
        MacShieldsExplanation()
        #endif
    }
}

struct MacShieldsExplanation: View {
    var body: some View {
        PaperPage(title: "Shields") {
            Text("Mac does not shield apps.")
                .font(.title3.weight(.medium))
                .foregroundStyle(TimePriceColor.ink)
            Text("Family Controls authorization fails under the Mac sandbox. The system looks up FamilyControlsAgent and returns error 159, so TimePrice does not call Family Controls on Mac.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.8))
            Text("The pause before spending is the Safari price, shown as hours of deep work, and wishlist links that open only after a focus session.")
                .foregroundStyle(TimePriceColor.ink.opacity(0.8))
        }
    }
}

#Preview {
    ShieldsView()
        .timePricePreview()
}

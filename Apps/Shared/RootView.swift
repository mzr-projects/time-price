import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.persistenceError != nil {
                persistenceError
            } else if model.needsOnboarding {
                OnboardingView()
            } else {
                tabs
            }
        }
        .tint(TimePriceColor.pine)
        .onOpenURL { model.handle(url: $0) }
        .onChange(of: scenePhase) { _, phase in
            model.handleScenePhase(phase)
        }
        .task(id: model.focusPhase) {
            guard model.focusPhase == .running else { return }
            while !Task.isCancelled {
                model.refreshFocus(at: Date())
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .task(id: model.currentGrantEndsAt) {
            guard let end = model.currentGrantEndsAt else { return }
            let remaining = end.timeIntervalSinceNow
            if remaining > 0 {
                let nanos = UInt64(remaining * 1_000_000_000) + 250_000_000
                try? await Task.sleep(nanoseconds: nanos)
            }
            model.reinforceShieldsIfGrantEnded()
        }
    }

    private var tabs: some View {
        @Bindable var model = model
        return TabView(selection: $model.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            NavigationStack { WishlistView() }
                .tabItem { Label("Wishlist", systemImage: "list.bullet") }
                .tag(AppTab.wishlist)
            NavigationStack { FocusTimerView() }
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(AppTab.focus)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }

    private var persistenceError: some View {
        PaperPage(title: "TimePrice") {
            Text(model.persistenceError ?? "TimePrice could not open its on-device store.")
                .foregroundStyle(TimePriceColor.ink)
        }
    }
}

extension View {
    func timePricePreview() -> some View {
        modifier(TimePricePreviewModifier())
    }
}

private struct TimePricePreviewModifier: ViewModifier {
    func body(content: Content) -> some View {
        let model = PreviewSupport.model
        if let container = model.container {
            content.environment(model).modelContainer(container)
        } else {
            content.environment(model)
        }
    }
}

@MainActor
enum PreviewSupport {
    static let model: AppModel = {
        let model = AppModel(inMemory: true)
        model.seedPreviewContent()
        return model
    }()
}

#Preview {
    RootView()
        .timePricePreview()
}

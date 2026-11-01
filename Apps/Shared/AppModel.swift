import Foundation
import SwiftData
import SwiftUI
import TimePriceCore

enum AppTab: Hashable {
    case home
    case wishlist
    case focus
    case settings
}

@MainActor
@Observable
final class AppModel {
    private(set) var container: ModelContainer?
    private(set) var persistenceError: String?
    var selectedTab: AppTab = .home
    var banner: String?
    var needsOnboarding = true
    var focusPhase: FocusPhase = .idle
    var requiredFocusMinutes = FocusEngine.defaultMinutes
    var unlockWindowMinutes = UnlockWindow.defaultMinutes
    var annotationEnabled = true

    let screenTime: any ScreenTimeControlling
    private var context: ModelContext?
    private var engine: FocusEngine
    private var ledger = GrantLedger()
    private let configStore: SharedConfigStore

    init(inMemory: Bool = false, screenTime: (any ScreenTimeControlling)? = nil) {
        self.screenTime = screenTime ?? NoopScreenTime()
        if let defaults = UserDefaults(suiteName: SharedConfig.appGroupID) {
            configStore = SharedConfigStore(defaults: defaults)
        } else {
            configStore = SharedConfigStore(defaults: .standard)
        }
        engine = FocusEngine(snapshot: FocusSnapshot(
            phase: .idle,
            requiredSeconds: FocusEngine.defaultMinutes * 60,
            accumulatedSeconds: 0,
            lastResumeDate: nil,
            startedAt: nil,
            backgroundedAt: nil,
            completedAt: nil
        ))
        let schema = Schema([
            WageProfileRecord.self,
            WishlistItemRecord.self,
            FocusSessionRecord.self,
            UnlockGrantRecord.self,
            DeepWorkLogRecord.self,
        ])
        do {
            let configuration = ModelConfiguration(
                "TimePrice",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: configuration)
            self.container = container
            context = container.mainContext
            persistenceError = nil
            load()
        } catch {
            container = nil
            context = nil
            persistenceError = "TimePrice could not open its on-device store. \(error.localizedDescription)"
        }
    }

    func remainingSeconds(at date: Date) -> Int {
        engine.remainingSeconds(at: date)
    }

    func grantIsActive(at date: Date) -> Bool {
        ledger.activeGrant(at: date) != nil
    }

    var currentGrantEndsAt: Date? {
        ledger.current?.endsAt
    }

    /// Backup for a late Device Activity callback while the app is open.
    func reinforceShieldsIfGrantEnded(at date: Date = Date()) {
        if ledger.activeGrant(at: date) == nil {
            screenTime.restoreShieldsIfNeeded()
        }
    }

    func activeGrant(at date: Date) -> UnlockGrant? {
        ledger.activeGrant(at: date)
    }

    func handleScenePhase(_ phase: ScenePhase, at date: Date = Date()) {
        switch phase {
        case .background:
            engine.noteBackground(at: date)
            touch()
        case .active:
            let event = engine.noteForeground(at: date)
            apply(event, at: date)
            if configStore.readWantsFocus() {
                handleIncomingFocus()
            }
            screenTime.restoreShieldsIfNeeded()
        default:
            break
        }
    }

    func handle(url: URL) {
        switch url.host?.lowercased() {
        case "focus":
            handleIncomingFocus()
        case "wishlist":
            selectedTab = .wishlist
        default:
            break
        }
    }

    func handleIncomingFocus() {
        selectedTab = .focus
        if configStore.consumeWantsFocus() {
            startOrResume()
        }
    }

    func startOrResume() {
        let now = Date()
        switch engine.phase {
        case .paused:
            try? engine.resume(at: now)
        case .idle, .completed, .failed:
            engine = (try? FocusEngine(requiredMinutes: requiredFocusMinutes)) ?? engine
            try? engine.start(at: now)
        case .running:
            break
        }
        selectedTab = .focus
        touch()
    }

    func pause() {
        let event = (try? engine.pause(at: Date())) ?? .none
        apply(event, at: Date())
    }

    func resume() {
        try? engine.resume(at: Date())
        touch()
    }

    func refreshFocus(at date: Date) {
        guard engine.phase == .running else { return }
        engine.checkpoint(at: date)
        let event = engine.refresh(at: date)
        apply(event, at: date)
        if ledger.activeGrant(at: date) == nil {
            screenTime.restoreShieldsIfNeeded()
        }
    }

    func saveWage(_ inputs: WageProfileInputs, finishOnboarding: Bool) {
        guard let context else { return }
        do {
            _ = try inputs.resolvedWage()
        } catch {
            banner = (error as? WageError)?.message ?? error.localizedDescription
            return
        }
        let profile = fetchProfile() ?? WageProfileRecord()
        if fetchProfile() == nil {
            context.insert(profile)
        }
        profile.apply(inputs)
        profile.annotationEnabled = annotationEnabled
        profile.requiredFocusMinutes = requiredFocusMinutes
        profile.unlockWindowMinutes = unlockWindowMinutes
        if finishOnboarding {
            profile.onboardingComplete = true
            needsOnboarding = false
        }
        save(context)
        publishSnapshot()
        banner = nil
    }

    func setRequiredFocusMinutes(_ minutes: Int) {
        guard FocusEngine.isAllowed(minutes: minutes) else {
            banner = FocusError.durationOutOfRange.message
            return
        }
        requiredFocusMinutes = minutes
        if engine.phase == .idle || engine.phase == .completed || engine.phase == .failed {
            try? engine.updateRequiredMinutes(minutes)
            touch()
        }
        updateProfilePreferences()
    }

    func setUnlockWindow(_ minutes: Int) {
        guard UnlockWindow(minutes: minutes) != nil else {
            banner = GrantError.windowNotAllowed.message
            return
        }
        unlockWindowMinutes = minutes
        updateProfilePreferences()
    }

    func setCurrency(_ code: String) {
        guard let currency = CurrencyCode(code) else {
            banner = WageError.invalidCurrency.message
            return
        }
        guard let context else { return }
        let profile = fetchProfile() ?? WageProfileRecord()
        if fetchProfile() == nil {
            context.insert(profile)
        }
        profile.currencyCode = currency.rawValue
        profile.updatedAt = Date()
        save(context)
        publishSnapshot()
        banner = nil
    }

    func setAnnotationEnabled(_ enabled: Bool) {
        annotationEnabled = enabled
        updateProfilePreferences()
    }

    func finishOnboarding() {
        guard let profile = fetchProfile() else {
            banner = "Enter a net hourly wage to continue."
            return
        }
        do {
            _ = try profile.inputs.resolvedWage()
        } catch {
            banner = (error as? WageError)?.message ?? error.localizedDescription
            return
        }
        profile.onboardingComplete = true
        needsOnboarding = false
        if let context { save(context) }
        publishSnapshot()
        banner = nil
    }

    func addWishlist(name: String, price: Decimal, currencyCode: String, urlString: String?) {
        guard let context else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = "Give the item a name."
            return
        }
        guard price >= 0 else {
            banner = TimeCostError.negativePrice.message
            return
        }
        guard CurrencyCode(currencyCode) != nil else {
            banner = WageError.invalidCurrency.message
            return
        }
        let url = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(
            WishlistItemRecord(
                name: trimmed,
                price: price.roundedPlain(scale: 2).plainString(scale: 2),
                currencyCode: CurrencyCode(currencyCode)?.rawValue ?? "USD",
                urlString: (url?.isEmpty == false) ? url : nil
            )
        )
        save(context)
        banner = nil
    }

    func deleteWishlist(_ item: WishlistItemRecord) {
        guard let context else { return }
        context.delete(item)
        save(context)
    }

    func updateWishlist(_ item: WishlistItemRecord, name: String, price: Decimal, currencyCode: String, urlString: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, price >= 0, let code = CurrencyCode(currencyCode) else {
            banner = "Check the name, price, and currency."
            return
        }
        item.name = trimmed
        item.price = price.roundedPlain(scale: 2).plainString(scale: 2)
        item.currencyCode = code.rawValue
        let url = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.urlString = (url?.isEmpty == false) ? url : nil
        if let context { save(context) }
        banner = nil
    }

    func urlToOpen(_ item: WishlistItemRecord, at date: Date) -> URL? {
        guard grantIsActive(at: date) else { return nil }
        guard let raw = item.urlString, let url = URL(string: raw) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    func importCSV(_ text: String) -> String {
        guard let context else { return "The on-device store is unavailable." }
        let existing = (try? context.fetch(FetchDescriptor<DeepWorkLogRecord>())) ?? []
        let result = CSVImporter.importCSV(text, existing: existing.map(\.entry), timeZone: .current)
        for entry in result.imported {
            context.insert(DeepWorkLogRecord(entry: entry))
        }
        save(context)
        var message = "Imported \(result.imported.count). Skipped \(result.skippedDuplicates) duplicates and \(result.skippedEmptyRows) empty rows."
        if !result.rowErrors.isEmpty {
            message += " \(result.rowErrors.count) rows could not be read."
        }
        return message
    }

    func timeCost(price: Decimal, currencyCode: String) -> String {
        guard let profile = fetchProfile() else { return "Set a wage to see hours." }
        guard let wage = try? profile.inputs.resolvedWage() else { return "Set a wage to see hours." }
        do {
            return try TimeCostMath.cost(
                price: price,
                priceCurrency: currencyCode,
                netHourly: wage.netHourly,
                wageCurrency: wage.currencyCode
            ).text
        } catch let error as TimeCostError {
            return error.message
        } catch {
            return error.localizedDescription
        }
    }

    func resolvedWageText() -> String {
        guard let profile = fetchProfile(), let wage = try? profile.inputs.resolvedWage() else {
            return "Wage not set"
        }
        return "\(wage.netHourlyText) \(wage.currencyCode) / hour"
    }

    func profileInputs() -> WageProfileInputs {
        fetchProfile()?.inputs ?? WageProfileInputs()
    }

    func seedPreviewContent() {
        guard let context, fetchProfile() == nil else { return }
        let profile = WageProfileRecord(
            activeSourceRaw: WageSource.direct.rawValue,
            currencyCode: "USD",
            directNetHourly: "32.0000",
            annualHours: "2080.00",
            annotationEnabled: true,
            requiredFocusMinutes: 25,
            unlockWindowMinutes: 15,
            onboardingComplete: true
        )
        context.insert(profile)
        context.insert(WishlistItemRecord(name: "Desk lamp", price: "48.00", currencyCode: "USD", urlString: "https://example.com/lamp"))
        let start = Date()
        context.insert(
            DeepWorkLogRecord(
                entry: DeepWorkEntry(
                    id: UUID(),
                    startedAt: start.addingTimeInterval(-1800),
                    endedAt: start,
                    focusedSeconds: 25 * 60,
                    source: .pomodoro
                )
            )
        )
        needsOnboarding = false
        save(context)
        publishSnapshot()
    }

    private func load() {
        guard let context else { return }
        if let profile = fetchProfile() {
            needsOnboarding = !profile.onboardingComplete
            if FocusEngine.isAllowed(minutes: profile.requiredFocusMinutes) {
                requiredFocusMinutes = profile.requiredFocusMinutes
            }
            if let window = UnlockWindow(minutes: profile.unlockWindowMinutes) {
                unlockWindowMinutes = window.rawValue
            }
            annotationEnabled = profile.annotationEnabled
        }
        if let record = (try? context.fetch(FetchDescriptor<FocusSessionRecord>()))?.first {
            engine = FocusEngine(snapshot: record.snapshot())
            _ = engine.noteRelaunch(at: Date())
            record.apply(engine.snapshot())
        }
        if let stored = (try? context.fetch(FetchDescriptor<UnlockGrantRecord>()))?.first {
            ledger = GrantLedger(current: stored.grant)
        }
        focusPhase = engine.phase
        save(context)
        publishSnapshot()
        screenTime.restoreShieldsIfNeeded()
    }

    private func apply(_ event: FocusEvent, at date: Date) {
        if case .completed(let elapsed) = event {
            recordCompletion(elapsed: elapsed, at: date)
        }
        touch()
    }

    private func recordCompletion(elapsed: Int, at date: Date) {
        guard let context else { return }
        let started = engine.startedAt ?? date.addingTimeInterval(-TimeInterval(elapsed))
        if let entry = DeepWorkLog.pomodoro(startedAt: started, endedAt: date, focusedSeconds: elapsed) {
            let existing = (try? context.fetch(FetchDescriptor<DeepWorkLogRecord>())) ?? []
            let duplicate = existing.contains { record in
                record.startedAt == entry.startedAt && record.endedAt == entry.endedAt
            }
            if !duplicate {
                context.insert(DeepWorkLogRecord(entry: entry))
            }
        }
        do {
            let grant = try ledger.issue(at: date, windowMinutes: unlockWindowMinutes)
            if let stored = (try? context.fetch(FetchDescriptor<UnlockGrantRecord>()))?.first {
                stored.apply(grant)
            } else {
                context.insert(
                    UnlockGrantRecord(
                        grantID: grant.id,
                        windowMinutes: grant.windowMinutes,
                        startsAt: grant.startsAt,
                        endsAt: grant.endsAt
                    )
                )
            }
            configStore.writeGrant(startsAt: grant.startsAt, endsAt: grant.endsAt)
            save(context)
            screenTime.unlockForActiveGrant()
            banner = "\(grant.windowMinutes) minutes are open."
        } catch {
            banner = (error as? GrantError)?.message ?? error.localizedDescription
            save(context)
        }
    }

    private func touch() {
        focusPhase = engine.phase
        persistFocus()
    }

    private func persistFocus() {
        guard let context else { return }
        let record = (try? context.fetch(FetchDescriptor<FocusSessionRecord>()))?.first ?? FocusSessionRecord()
        if (try? context.fetch(FetchDescriptor<FocusSessionRecord>()))?.isEmpty != false {
            context.insert(record)
        }
        record.apply(engine.snapshot())
        save(context)
    }

    private func updateProfilePreferences() {
        guard let profile = fetchProfile() else {
            publishSnapshot()
            return
        }
        profile.annotationEnabled = annotationEnabled
        profile.requiredFocusMinutes = requiredFocusMinutes
        profile.unlockWindowMinutes = unlockWindowMinutes
        profile.updatedAt = Date()
        if let context { save(context) }
        publishSnapshot()
    }

    private func publishSnapshot() {
        let wage = fetchProfile().flatMap { try? $0.inputs.resolvedWage() }
        let snapshot = SharedConfigSnapshot(
            netHourly: wage?.netHourlyText ?? "",
            currencyCode: wage?.currencyCode ?? (fetchProfile()?.currencyCode ?? "USD"),
            enabled: annotationEnabled && wage != nil,
            requiredFocusMinutes: requiredFocusMinutes,
            unlockWindowMinutes: unlockWindowMinutes
        )
        configStore.write(snapshot)
        if let grant = ledger.current {
            configStore.writeGrant(startsAt: grant.startsAt, endsAt: grant.endsAt)
        }
    }

    private func fetchProfile() -> WageProfileRecord? {
        guard let context else { return nil }
        return (try? context.fetch(FetchDescriptor<WageProfileRecord>()))?.first
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            banner = "TimePrice could not save that change on this device."
        }
    }
}

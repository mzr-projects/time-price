import Foundation
import SwiftData
import TimePriceCore

enum DecimalStorage {
    static func text(_ value: Decimal?, scale: Int) -> String? {
        value?.plainString(scale: scale)
    }

    static func decimal(_ text: String?) -> Decimal? {
        guard let text, !text.isEmpty else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
}

@Model
class WageProfileRecord {
    var activeSourceRaw: String
    var currencyCode: String
    var directNetHourly: String?
    var annualGross: String?
    var taxRate: String?
    var annualWorkExpenses: String?
    var annualHours: String
    var annotationEnabled: Bool
    var requiredFocusMinutes: Int
    var unlockWindowMinutes: Int
    var onboardingComplete: Bool
    var updatedAt: Date

    init(
        activeSourceRaw: String = WageSource.direct.rawValue,
        currencyCode: String = "USD",
        directNetHourly: String? = nil,
        annualGross: String? = nil,
        taxRate: String? = nil,
        annualWorkExpenses: String? = nil,
        annualHours: String = "2080.00",
        annotationEnabled: Bool = true,
        requiredFocusMinutes: Int = FocusEngine.defaultMinutes,
        unlockWindowMinutes: Int = UnlockWindow.defaultMinutes,
        onboardingComplete: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.activeSourceRaw = activeSourceRaw
        self.currencyCode = currencyCode
        self.directNetHourly = directNetHourly
        self.annualGross = annualGross
        self.taxRate = taxRate
        self.annualWorkExpenses = annualWorkExpenses
        self.annualHours = annualHours
        self.annotationEnabled = annotationEnabled
        self.requiredFocusMinutes = requiredFocusMinutes
        self.unlockWindowMinutes = unlockWindowMinutes
        self.onboardingComplete = onboardingComplete
        self.updatedAt = updatedAt
    }

    var inputs: WageProfileInputs {
        WageProfileInputs(
            activeSource: WageSource(rawValue: activeSourceRaw) ?? .direct,
            currencyCode: currencyCode,
            directNetHourly: DecimalStorage.decimal(directNetHourly),
            annualGross: DecimalStorage.decimal(annualGross),
            taxRate: DecimalStorage.decimal(taxRate),
            annualWorkExpenses: DecimalStorage.decimal(annualWorkExpenses),
            annualHours: DecimalStorage.decimal(annualHours) ?? WageDerivation.defaultAnnualHours
        )
    }

    func apply(_ inputs: WageProfileInputs) {
        activeSourceRaw = inputs.activeSource.rawValue
        currencyCode = inputs.currencyCode
        directNetHourly = DecimalStorage.text(inputs.directNetHourly, scale: 4)
        annualGross = DecimalStorage.text(inputs.annualGross, scale: 2)
        taxRate = DecimalStorage.text(inputs.taxRate, scale: 6)
        annualWorkExpenses = DecimalStorage.text(inputs.annualWorkExpenses, scale: 2)
        annualHours = inputs.annualHours.plainString(scale: 2)
        updatedAt = Date()
    }
}

@Model
class WishlistItemRecord {
    var name: String
    var price: String
    var currencyCode: String
    var urlString: String?
    var createdAt: Date

    init(name: String, price: String, currencyCode: String, urlString: String?, createdAt: Date = Date()) {
        self.name = name
        self.price = price
        self.currencyCode = currencyCode
        self.urlString = urlString
        self.createdAt = createdAt
    }

    var priceDecimal: Decimal {
        DecimalStorage.decimal(price) ?? 0
    }
}

@Model
class FocusSessionRecord {
    var phaseRaw: String
    var requiredSeconds: Int
    var accumulatedSeconds: Int
    var lastResumeAt: Date?
    var startedAt: Date?
    var backgroundedAt: Date?
    var completedAt: Date?

    init(
        phaseRaw: String = FocusPhase.idle.rawValue,
        requiredSeconds: Int = FocusEngine.defaultMinutes * 60,
        accumulatedSeconds: Int = 0,
        lastResumeAt: Date? = nil,
        startedAt: Date? = nil,
        backgroundedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.phaseRaw = phaseRaw
        self.requiredSeconds = requiredSeconds
        self.accumulatedSeconds = accumulatedSeconds
        self.lastResumeAt = lastResumeAt
        self.startedAt = startedAt
        self.backgroundedAt = backgroundedAt
        self.completedAt = completedAt
    }

    func snapshot() -> FocusSnapshot {
        FocusSnapshot(
            phase: FocusPhase(rawValue: phaseRaw) ?? .idle,
            requiredSeconds: requiredSeconds,
            accumulatedSeconds: accumulatedSeconds,
            lastResumeDate: lastResumeAt,
            startedAt: startedAt,
            backgroundedAt: backgroundedAt,
            completedAt: completedAt
        )
    }

    func apply(_ snapshot: FocusSnapshot) {
        phaseRaw = snapshot.phase.rawValue
        requiredSeconds = snapshot.requiredSeconds
        accumulatedSeconds = snapshot.accumulatedSeconds
        lastResumeAt = snapshot.lastResumeDate
        startedAt = snapshot.startedAt
        backgroundedAt = snapshot.backgroundedAt
        completedAt = snapshot.completedAt
    }
}

@Model
class UnlockGrantRecord {
    var grantID: UUID
    var windowMinutes: Int
    var startsAt: Date
    var endsAt: Date

    init(grantID: UUID, windowMinutes: Int, startsAt: Date, endsAt: Date) {
        self.grantID = grantID
        self.windowMinutes = windowMinutes
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    var grant: UnlockGrant {
        UnlockGrant(id: grantID, windowMinutes: windowMinutes, startsAt: startsAt, endsAt: endsAt)
    }

    func apply(_ grant: UnlockGrant) {
        grantID = grant.id
        windowMinutes = grant.windowMinutes
        startsAt = grant.startsAt
        endsAt = grant.endsAt
    }
}

@Model
class DeepWorkLogRecord {
    var entryID: UUID
    var startedAt: Date
    var endedAt: Date
    var focusedSeconds: Int
    var sourceRaw: String

    init(entryID: UUID, startedAt: Date, endedAt: Date, focusedSeconds: Int, sourceRaw: String) {
        self.entryID = entryID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusedSeconds = focusedSeconds
        self.sourceRaw = sourceRaw
    }

    convenience init(entry: DeepWorkEntry) {
        self.init(
            entryID: entry.id,
            startedAt: entry.startedAt,
            endedAt: entry.endedAt,
            focusedSeconds: entry.focusedSeconds,
            sourceRaw: entry.source.rawValue
        )
    }

    var entry: DeepWorkEntry {
        DeepWorkEntry(
            id: entryID,
            startedAt: startedAt,
            endedAt: endedAt,
            focusedSeconds: focusedSeconds,
            source: DeepWorkSource(rawValue: sourceRaw) ?? .csv
        )
    }
}

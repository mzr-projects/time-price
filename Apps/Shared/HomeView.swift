import SwiftData
import SwiftUI
import TimePriceCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \WishlistItemRecord.createdAt, order: .reverse) private var items: [WishlistItemRecord]
    @Query(sort: \DeepWorkLogRecord.startedAt, order: .reverse) private var log: [DeepWorkLogRecord]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            PaperPage(title: "TimePrice") {
                Text(model.resolvedWageText())
                    .font(.title2.weight(.medium))
                    .foregroundStyle(TimePriceColor.ink)
                    .accessibilityLabel(model.resolvedWageText())

                Card {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(TimePriceColor.ink.opacity(0.7))
                    NumeralText(
                        text: focusedText(on: context.date, week: false),
                        accessibilityLabel: "Focused today, \(focusedText(on: context.date, week: false))"
                    )
                }
                Card {
                    Text("This week")
                        .font(.subheadline)
                        .foregroundStyle(TimePriceColor.ink.opacity(0.7))
                    NumeralText(
                        text: focusedText(on: context.date, week: true),
                        accessibilityLabel: "Focused this week, \(focusedText(on: context.date, week: true))"
                    )
                }

                if let grant = model.activeGrant(at: context.date) {
                    let remaining = max(0, Int(grant.endsAt.timeIntervalSince(context.date).rounded(.down)))
                    Text("\(DurationText.format(totalSeconds: remaining)) left on the current unlock.")
                        .foregroundStyle(TimePriceColor.ink.opacity(0.8))
                }

                Text("Wishlist")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(TimePriceColor.ink)
                    .accessibilityAddTraits(.isHeader)
                if items.isEmpty {
                    Text("Nothing is waiting.")
                        .foregroundStyle(TimePriceColor.ink.opacity(0.72))
                } else {
                    ForEach(items.prefix(3)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                                .foregroundStyle(TimePriceColor.ink)
                            Text(model.timeCost(price: item.priceDecimal, currencyCode: item.currencyCode))
                                .foregroundStyle(TimePriceColor.pine)
                            Text("\(item.price) \(item.currencyCode)")
                                .font(.footnote)
                                .foregroundStyle(TimePriceColor.ink.opacity(0.65))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Button("Start focus") { model.startOrResume() }
                    .buttonStyle(PineButtonStyle())
            }
        }
    }

    private func focusedText(on date: Date, week: Bool) -> String {
        let entries = log.map(\.entry)
        let seconds = week
            ? DeepWorkLog.focusedSeconds(inWeekOf: date, entries: entries, calendar: .current)
            : DeepWorkLog.focusedSeconds(on: date, entries: entries, calendar: .current)
        return DurationText.format(totalSeconds: seconds)
    }
}

#Preview {
    HomeView()
        .timePricePreview()
}

import SwiftData
import SwiftUI
import TimePriceCore

struct WishlistView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Query(sort: \WishlistItemRecord.createdAt, order: .reverse) private var items: [WishlistItemRecord]
    @State private var editor: WishlistItemRecord?
    @State private var showingNew = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            PaperPage(title: "Wishlist") {
                if items.isEmpty {
                    Text("Add a price to see it in hours of deep work.")
                        .foregroundStyle(TimePriceColor.ink.opacity(0.75))
                }
                ForEach(items) { item in
                    wishlistRow(item, now: context.date)
                }
                Button("Add item") { showingNew = true }
                    .buttonStyle(PineButtonStyle())
                    .accessibilityHint("Opens a form for a name and a price.")
            }
        }
        .sheet(isPresented: $showingNew) {
            WishlistEditor(item: nil)
        }
        .sheet(item: $editor) { item in
            WishlistEditor(item: item)
        }
    }

    private func wishlistRow(_ item: WishlistItemRecord, now: Date) -> some View {
        Card {
            Button {
                editor = item
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(TimePriceColor.ink)
                    Text(model.timeCost(price: item.priceDecimal, currencyCode: item.currencyCode))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(TimePriceColor.pine)
                    Text("\(item.price) \(item.currencyCode)")
                        .font(.footnote)
                        .foregroundStyle(TimePriceColor.ink.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edits this item.")

            if item.urlString != nil {
                if model.grantIsActive(at: now) {
                    Button("Open") {
                        if let url = model.urlToOpen(item, at: now) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(PineButtonStyle())
                    .accessibilityHint("Opens the link while the unlock is active.")
                } else {
                    Button("Earn to open") { model.startOrResume() }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityHint("Starts or resumes a focus session. The link opens after it finishes.")
                }
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) { model.deleteWishlist(item) }
        }
    }
}

struct WishlistEditor: View {
    var item: WishlistItemRecord?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var currency = "USD"
    @State private var url = ""

    var body: some View {
        NavigationStack {
            PaperPage(title: item == nil ? "Add item" : "Edit item") {
                labeled("Name", text: $name)
                labeled("Price", text: $price)
                Picker("Currency", selection: $currency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                }
                .accessibilityLabel("Currency")
                labeled("Link, optional", text: $url)
                Button("Save") { save() }
                    .buttonStyle(PineButtonStyle())
                if item != nil {
                    Button("Delete") {
                        if let item { model.deleteWishlist(item) }
                        dismiss()
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityHint("Removes this item from the wishlist.")
                }
            }
            .navigationTitle(item == nil ? "Add item" : "Edit item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if let item {
                name = item.name
                price = item.price
                currency = item.currencyCode
                url = item.urlString ?? ""
            } else {
                currency = model.profileInputs().currencyCode
            }
        }
    }

    private func labeled(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TimePriceColor.ink)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(TimePriceColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(title)
        }
    }

    private func save() {
        guard let amount = DecimalMath.parseUserNumber(price) else {
            model.banner = "Enter a price."
            return
        }
        if let item {
            model.updateWishlist(item, name: name, price: amount, currencyCode: currency, urlString: url)
        } else {
            model.addWishlist(name: name, price: amount, currencyCode: currency, urlString: url)
        }
        dismiss()
    }
}

#Preview {
    WishlistView()
        .timePricePreview()
}

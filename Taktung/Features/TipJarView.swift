import SwiftUI
import StoreKit

struct TipJarView: View {
    @Environment(TipStore.self) private var store
    @Environment(\.purchase) private var purchase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            Section {
                Text("If Taktung helps with your work, a tip is a way to support its development. Thank you.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                ForEach(TipStore.catalog) { option in
                    tipRow(option)
                }
            } footer: {
                Text("Tips are optional, can be given more than once, and don’t unlock features. Apple handles payment in your App Store currency.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.canMakePayments {
                Section {
                    Label("In-app purchases are disabled on this device.", systemImage: "lock")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("tips.restricted")
                }
            } else if !store.isLoading && (store.loadError != nil || store.productsByID.count < TipStore.catalog.count) {
                Section {
                    Text(store.loadError ?? "Some tips aren’t available right now. You can try loading their prices again.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try again", systemImage: "arrow.clockwise") {
                        Task { await store.loadProducts() }
                    }
                    .disabled(store.isLoading || store.purchasingID != nil)
                    .accessibilityIdentifier("tips.retry")
                } header: { Text("App Store unavailable") }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).taktCanvas()
        .navigationTitle("Tip Jar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadProducts() }
    }

    private func tipRow(_ option: TipOption) -> some View {
        let product = store.productsByID[option.id]
        let available = product != nil && store.canMakePayments
        return Button {
            let purchase = purchase
            Task {
                await store.purchase(option, using: { product in
                    try await purchase(product)
                })
            }
        } label: {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text(option.name)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    if store.purchasingID == option.id {
                        ProgressView().accessibilityLabel("Waiting for Apple")
                    } else if let product {
                        Text(product.displayPrice)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Palette.accent.opacity(0.12), in: .capsule)
                    } else if store.isLoading {
                        ProgressView().accessibilityLabel("Loading price")
                    } else {
                        Text("Unavailable").foregroundStyle(.secondary)
                    }
                }
                .fixedSize()
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .disabled(!available || store.purchasingID != nil)
        .accessibilityIdentifier("tips.\(option.id)")
        .accessibilityLabel("\(option.name), \(product?.displayPrice ?? (store.isLoading ? "loading price" : "unavailable"))")
        .accessibilityHint(available ? "One-time tip. Opens Apple’s purchase sheet." : "This tip cannot be purchased right now.")
    }
}

/// The sheet's navigation container owns the alert, so its presenting focus
/// environment stays alive when the user goes back immediately after checkout.
struct TipPurchaseNotice: ViewModifier {
    @Environment(TipStore.self) private var store

    func body(content: Content) -> some View {
        content.alert(store.notice?.title ?? "Tip Jar", isPresented: Binding(
            get: { store.notice != nil },
            set: { if !$0 { store.dismissNotice() } }
        )) {
            Button("OK", role: .cancel) { store.dismissNotice() }
        } message: {
            Text(store.notice?.message ?? "")
        }
    }
}

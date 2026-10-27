import Foundation
import Observation
import StoreKit

/// Repeatable, optional purchases. A tip never unlocks an app feature or an entitlement.
struct TipOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    static let catalog: [TipOption] = [
        .init(id: "com.jcollins.takt.tip.kind", name: "Kind Tip"),
        .init(id: "com.jcollins.takt.tip.thoughtful", name: "Thoughtful Tip"),
        .init(id: "com.jcollins.takt.tip.wonderful", name: "Wonderful Tip"),
        .init(id: "com.jcollins.takt.tip.incredible", name: "Incredible Tip"),
        .init(id: "com.jcollins.takt.tip.extraordinary", name: "Extraordinary Tip")
    ]
}

/// The only price shown by the app is the storefront's localized `Product.displayPrice`.
struct TipProduct: Equatable, Sendable {
    let id: String
    let displayPrice: String
    let isConsumable: Bool
}

struct TipNotice: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable { case thanks, pending, error }
    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}

/// Only a verified transaction can expose a finish operation to the model.
struct TipTransaction: Sendable {
    let id: UInt64
    let productID: String
    let isConsumable: Bool
    let isPurchased: Bool
    let isRevoked: Bool
    let finish: @Sendable () async -> Void
}

enum TipTransactionResult: Sendable {
    case verified(TipTransaction)
    case unverified
}

enum TipPurchaseResult: Sendable {
    case transaction(TipTransactionResult)
    case cancelled
    case pending
}

/// The initiating view supplies StoreKit's purchase action with its own scene context.
typealias TipPurchaseAction = @MainActor (Product) async throws -> Product.PurchaseResult

@MainActor
protocol TipStorefront {
    var canMakePayments: Bool { get }
    func products(for identifiers: [String]) async throws -> [TipProduct]
    func purchase(productID: String, using action: TipPurchaseAction?) async throws -> TipPurchaseResult
    func transactionUpdates() -> AsyncStream<TipTransactionResult>
}

/// Main-app only. There are no receipts, transaction records or purchase flags on disk.
@MainActor @Observable
final class TipStore {
    static let catalog = TipOption.catalog

    private(set) var productsByID: [String: TipProduct] = [:]
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var purchasingID: String?
    private(set) var canMakePayments: Bool
    private(set) var notice: TipNotice?

    @ObservationIgnored private let storefront: any TipStorefront
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    // Bound duplicate-delivery bookkeeping to this process. This is not a purchase history.
    @ObservationIgnored private var recentTransactionIDs: [UInt64] = []
    @ObservationIgnored private var processedIDs: Set<UInt64> = []
    @ObservationIgnored private var thankedIDs: Set<UInt64> = []
    @ObservationIgnored private var pendingProductID: String?
    private static let duplicateWindow = 128

    init(storefront: any TipStorefront = AppleTipStorefront()) {
        self.storefront = storefront
        canMakePayments = storefront.canMakePayments
    }

    deinit { updateTask?.cancel() }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        canMakePayments = storefront.canMakePayments
        productsByID = [:]
        defer { isLoading = false }
        do {
            let products = try await storefront.products(for: Self.catalog.map(\.id))
            try Task.checkCancellation()
            let ownedIDs = Set(Self.catalog.map(\.id))
            for product in products where ownedIDs.contains(product.id) && product.isConsumable {
                productsByID[product.id] = product
            }
            if productsByID.isEmpty {
                loadError = "Tips aren’t available right now. Please try again later."
            }
        } catch is CancellationError {
            // Leaving a screen while prices load is not a storefront failure.
        } catch {
            loadError = "Tip prices couldn’t be loaded. Check your connection and try again."
        }
    }

    func purchase(_ option: TipOption, using action: TipPurchaseAction? = nil) async {
        // The guard is set before the first suspension, including across different tip rows.
        guard purchasingID == nil, Self.catalog.contains(option) else { return }
        canMakePayments = storefront.canMakePayments
        guard canMakePayments else {
            showError("In-app purchases aren’t allowed on this device.")
            return
        }
        guard productsByID[option.id] != nil else {
            showError("This tip isn’t available right now. Reload the prices and try again.")
            return
        }
        purchasingID = option.id
        notice = nil
        defer { purchasingID = nil }
        do {
            switch try await storefront.purchase(productID: option.id, using: action) {
            case .cancelled:
                break
            case .pending:
                pendingProductID = option.id
                notice = TipNotice(kind: .pending, title: "Tip awaiting approval", message: "Apple will complete the tip after it’s approved. You can keep using Taktung as usual.")
            case .transaction(.unverified):
                showError("Apple’s purchase verification couldn’t be confirmed. Please try again later.")
            case .transaction(.verified(let transaction)):
                guard transaction.productID == option.id,
                      await finishIfOwned(transaction) else {
                    showError("This purchase couldn’t be confirmed as a Taktung tip.")
                    return
                }
                if thankedIDs.insert(transaction.id).inserted {
                    notice = TipNotice(kind: .thanks, title: "Thank you", message: "Your tip helps support Taktung’s development.")
                }
            }
        } catch is CancellationError {
            // Task cancellation is separate from a failed purchase.
        } catch {
            showError("The tip couldn’t be completed. Please try again later.")
        }
    }

    /// Start at app launch, rather than only while the tip screen is visible, for pending purchases.
    func startTransactionListener() {
        guard updateTask == nil else { return }
        let updates = storefront.transactionUpdates()
        updateTask = Task { [weak self] in
            for await result in updates {
                guard !Task.isCancelled, let self else { break }
                if case .verified(let transaction) = result {
                    if await self.finishIfOwned(transaction), self.pendingProductID == transaction.productID {
                        self.pendingProductID = nil
                        if self.notice?.kind == .pending { self.notice = nil }
                    }
                }
                // Old or approved purchases are acknowledged quietly. No launch-time thank-you.
            }
        }
    }

    func stopTransactionListener() {
        updateTask?.cancel()
        updateTask = nil
    }

    func dismissNotice() { notice = nil }

    private func showError(_ message: String) {
        notice = TipNotice(kind: .error, title: "Tip unavailable", message: message)
    }

    private func finishIfOwned(_ transaction: TipTransaction) async -> Bool {
        guard Self.catalog.contains(where: { $0.id == transaction.productID }),
              transaction.isConsumable, transaction.isPurchased, !transaction.isRevoked else { return false }
        guard processedIDs.insert(transaction.id).inserted else { return true }
        recentTransactionIDs.append(transaction.id)
        if recentTransactionIDs.count > Self.duplicateWindow {
            let expired = recentTransactionIDs.removeFirst()
            processedIDs.remove(expired)
            thankedIDs.remove(expired)
        }
        // Mark before awaiting: direct purchase and Transaction.updates can deliver the same tip.
        await transaction.finish()
        return true
    }
}

@MainActor
private final class AppleTipStorefront: TipStorefront {
    private var productsByID: [String: Product] = [:]
    var canMakePayments: Bool { AppStore.canMakePayments }

    func products(for identifiers: [String]) async throws -> [TipProduct] {
        let products = try await Product.products(for: identifiers)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return products.map { TipProduct(id: $0.id, displayPrice: $0.displayPrice, isConsumable: $0.type == .consumable) }
    }

    func purchase(productID: String, using action: TipPurchaseAction?) async throws -> TipPurchaseResult {
        guard let product = productsByID[productID], product.type == .consumable else {
            throw Product.PurchaseError.productUnavailable
        }
        do {
            let result: Product.PurchaseResult
            if let action {
                result = try await action(product)
            } else {
                // Local non-UI StoreKit integration tests have no presenting view.
                result = try await product.purchase()
            }
            switch result {
            case .success(let result): return .transaction(Self.map(result))
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: throw Product.PurchaseError.productUnavailable
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        }
    }

    func transactionUpdates() -> AsyncStream<TipTransactionResult> {
        AsyncStream { continuation in
            let updateTask = Task {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    continuation.yield(Self.map(result))
                }
                continuation.finish()
            }
            // Consumables can remain unfinished if the app exits between verification and finish.
            // Subscribe to updates as well; the model deduplicates either delivery order.
            let unfinishedTask = Task {
                for await result in Transaction.unfinished {
                    guard !Task.isCancelled else { break }
                    continuation.yield(Self.map(result))
                }
            }
            continuation.onTermination = { _ in
                updateTask.cancel()
                unfinishedTask.cancel()
            }
        }
    }

    private static func map(_ result: VerificationResult<Transaction>) -> TipTransactionResult {
        switch result {
        case .unverified: return .unverified
        case .verified(let transaction):
            return .verified(TipTransaction(
                id: transaction.id,
                productID: transaction.productID,
                isConsumable: transaction.productType == .consumable,
                isPurchased: transaction.ownershipType == .purchased,
                isRevoked: transaction.revocationDate != nil,
                finish: { await transaction.finish() }
            ))
        }
    }
}

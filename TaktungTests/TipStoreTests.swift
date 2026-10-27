import Foundation
import Testing
@testable import Taktung

/// Synthetic storefront results exercise the purchase lifecycle without charging an account.
@Suite @MainActor
struct TipStoreTests {
    private enum TestError: Error { case unavailable }

    private final class Storefront: TipStorefront {
        var canMakePayments = true
        var offeredProducts = TipOption.catalog.enumerated().map {
            TipProduct(id: $0.element.id, displayPrice: ["$0.99", "$1.99", "$2.99", "$3.99", "$4.99"][$0.offset], isConsumable: true)
        }
        var productsError = false
        var purchaseError = false
        var cancelPurchaseTask = false
        var purchaseResult = TipPurchaseResult.cancelled
        var onLoad: (() async -> Void)?
        var onPurchase: (() async -> Void)?
        var productRequests: [[String]] = []
        var purchaseRequests: [String] = []
        var listenerCount = 0
        let stream: AsyncStream<TipTransactionResult>
        let continuation: AsyncStream<TipTransactionResult>.Continuation

        init() {
            (stream, continuation) = AsyncStream.makeStream()
        }

        func products(for identifiers: [String]) async throws -> [TipProduct] {
            productRequests.append(identifiers)
            await onLoad?()
            if productsError { throw TestError.unavailable }
            return offeredProducts
        }

        func purchase(productID: String, using action: TipPurchaseAction?) async throws -> TipPurchaseResult {
            purchaseRequests.append(productID)
            await onPurchase?()
            if cancelPurchaseTask { throw CancellationError() }
            if purchaseError { throw TestError.unavailable }
            return purchaseResult
        }

        func transactionUpdates() -> AsyncStream<TipTransactionResult> {
            listenerCount += 1
            return stream
        }
    }

    @MainActor private final class FinishCounter {
        var calls = 0
        func finish() { calls += 1 }
    }

    private func transaction(id: UInt64 = 1, productID: String = "com.jcollins.takt.tip.kind", consumable: Bool = true,
                             purchased: Bool = true, revoked: Bool = false,
                             counter: FinishCounter) -> TipTransaction {
        TipTransaction(id: id, productID: productID, isConsumable: consumable,
                       isPurchased: purchased, isRevoked: revoked,
                       finish: { await counter.finish() })
    }

    @Test func catalogHasStableNamesAndOrder() {
        #expect(TipStore.catalog.map(\.id) == ["com.jcollins.takt.tip.kind", "com.jcollins.takt.tip.thoughtful", "com.jcollins.takt.tip.wonderful", "com.jcollins.takt.tip.incredible", "com.jcollins.takt.tip.extraordinary"])
        #expect(TipStore.catalog.map(\.name) == ["Kind Tip", "Thoughtful Tip", "Wonderful Tip", "Incredible Tip", "Extraordinary Tip"])
    }

    @Test func pricesComeFromStorefrontAndPartialAvailabilityIsPreserved() async {
        let storefront = Storefront()
        storefront.offeredProducts = [
            TipProduct(id: "com.jcollins.takt.tip.thoughtful", displayPrice: "1,99 €", isConsumable: true),
            TipProduct(id: "other.product", displayPrice: "₩3,000", isConsumable: true),
            TipProduct(id: "com.jcollins.takt.tip.wonderful", displayPrice: "$2.99", isConsumable: false)
        ]
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        #expect(storefront.productRequests == [TipStore.catalog.map(\.id)])
        #expect(store.productsByID.count == 1)
        #expect(store.productsByID["com.jcollins.takt.tip.thoughtful"]?.displayPrice == "1,99 €")
        #expect(store.loadError == nil)
        #expect(!store.isLoading)
        await store.purchase(TipStore.catalog[0])
        #expect(storefront.purchaseRequests.isEmpty)
        #expect(store.notice?.kind == .error)
    }

    @Test func emptyAndFailedLoadsCanBeRetriedWithoutInventingPrices() async {
        let storefront = Storefront()
        let store = TipStore(storefront: storefront)
        storefront.offeredProducts = []
        await store.loadProducts()
        #expect(store.productsByID.isEmpty)
        #expect(store.loadError != nil)
        storefront.productsError = true
        await store.loadProducts()
        #expect(store.productsByID.isEmpty)
        #expect(store.loadError != nil)
        storefront.productsError = false
        storefront.offeredProducts = [TipProduct(id: "com.jcollins.takt.tip.kind", displayPrice: "¥150", isConsumable: true)]
        await store.loadProducts()
        #expect(store.productsByID["com.jcollins.takt.tip.kind"]?.displayPrice == "¥150")
        #expect(store.loadError == nil)
    }

    @Test func concurrentLoadsDoNotDuplicateStoreRequests() async {
        let storefront = Storefront()
        var resume: CheckedContinuation<Void, Never>?
        storefront.onLoad = { await withCheckedContinuation { resume = $0 } }
        let store = TipStore(storefront: storefront)
        let first = Task { await store.loadProducts() }
        await eventually { resume != nil }
        #expect(store.isLoading)
        await store.loadProducts()
        #expect(storefront.productRequests.count == 1)
        resume?.resume()
        await first.value
        #expect(!store.isLoading)
    }

    @Test func paymentRestrictionIsCheckedAgainAtPurchaseTime() async {
        let storefront = Storefront()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        storefront.canMakePayments = false
        await store.purchase(TipStore.catalog[0])
        #expect(!store.canMakePayments)
        #expect(storefront.purchaseRequests.isEmpty)
        #expect(store.notice?.kind == .error)
        #expect(store.purchasingID == nil)
    }

    @Test func cancellationIsQuietAndPendingDoesNotCreateAnEntitlement() async {
        let storefront = Storefront()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        await store.purchase(TipStore.catalog[0])
        #expect(store.notice == nil)
        #expect(store.purchasingID == nil)
        storefront.purchaseResult = .pending
        await store.purchase(TipStore.catalog[0])
        #expect(store.notice?.kind == .pending)
        #expect(store.purchasingID == nil)
        store.dismissNotice()
        storefront.purchaseResult = .cancelled
        await store.purchase(TipStore.catalog[0])
        #expect(storefront.purchaseRequests.count == 3)
        #expect(store.notice == nil)
    }

    @Test func errorsAndUnverifiedPurchasesNeverThankTheUser() async {
        let storefront = Storefront()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        storefront.purchaseError = true
        await store.purchase(TipStore.catalog[0])
        #expect(store.notice?.kind == .error)
        #expect(store.purchasingID == nil)
        storefront.purchaseError = false
        storefront.purchaseResult = .transaction(.unverified)
        await store.purchase(TipStore.catalog[0])
        #expect(store.notice?.kind == .error)
        #expect(store.purchasingID == nil)
    }

    @Test func cancellingThePurchaseTaskDoesNotShowAnError() async {
        let storefront = Storefront()
        storefront.cancelPurchaseTask = true
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        await store.purchase(TipStore.catalog[0])
        #expect(store.notice == nil)
        #expect(store.purchasingID == nil)
    }

    @Test func overlappingTapRequestsDoNotPresentMultiplePurchases() async {
        let storefront = Storefront()
        var resume: CheckedContinuation<Void, Never>?
        storefront.onPurchase = { await withCheckedContinuation { resume = $0 } }
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        let first = Task { await store.purchase(TipStore.catalog[0]) }
        await eventually { resume != nil }
        #expect(store.purchasingID == "com.jcollins.takt.tip.kind")
        await store.purchase(TipStore.catalog[0])
        await store.purchase(TipStore.catalog[4])
        #expect(storefront.purchaseRequests == ["com.jcollins.takt.tip.kind"])
        resume?.resume()
        await first.value
        #expect(store.purchasingID == nil)
    }

    @Test func verifiedTipsFinishAndRemainRepeatable() async {
        let storefront = Storefront()
        let counter = FinishCounter()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        storefront.purchaseResult = .transaction(.verified(transaction(counter: counter)))
        await store.purchase(TipStore.catalog[0])
        #expect(counter.calls == 1)
        #expect(store.notice?.kind == .thanks)
        store.dismissNotice()
        storefront.purchaseResult = .transaction(.verified(transaction(id: 2, counter: counter)))
        await store.purchase(TipStore.catalog[0])
        #expect(counter.calls == 2)
        #expect(store.notice?.kind == .thanks)
        #expect(storefront.purchaseRequests == ["com.jcollins.takt.tip.kind", "com.jcollins.takt.tip.kind"])
        #expect(store.productsByID["com.jcollins.takt.tip.kind"] != nil)
    }

    @Test func verifiedPurchaseForDifferentProductIsNotFinished() async {
        let storefront = Storefront()
        let counter = FinishCounter()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        storefront.purchaseResult = .transaction(.verified(transaction(productID: "com.jcollins.takt.tip.extraordinary", counter: counter)))
        await store.purchase(TipStore.catalog[0])
        #expect(counter.calls == 0)
        #expect(store.notice?.kind == .error)
    }

    @Test func listenerFinishesPendingApprovalQuietlyAndStartsOnlyOnce() async {
        let storefront = Storefront()
        let counter = FinishCounter()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        storefront.purchaseResult = .pending
        await store.purchase(TipStore.catalog[0])
        #expect(store.notice?.kind == .pending)
        store.startTransactionListener()
        store.startTransactionListener()
        #expect(storefront.listenerCount == 1)
        storefront.continuation.yield(.verified(transaction(counter: counter)))
        await eventually { counter.calls == 1 }
        #expect(store.notice == nil)
        #expect(store.purchasingID == nil)
        store.stopTransactionListener()
    }

    @Test func unverifiedUnknownNonConsumableSharedAndRevokedUpdatesAreNotFinished() async {
        let storefront = Storefront()
        let rejected = FinishCounter()
        let sentinel = FinishCounter()
        let store = TipStore(storefront: storefront)
        store.startTransactionListener()
        storefront.continuation.yield(.unverified)
        storefront.continuation.yield(.verified(transaction(id: 1, productID: "other.product", counter: rejected)))
        storefront.continuation.yield(.verified(transaction(id: 2, consumable: false, counter: rejected)))
        storefront.continuation.yield(.verified(transaction(id: 3, purchased: false, counter: rejected)))
        storefront.continuation.yield(.verified(transaction(id: 4, revoked: true, counter: rejected)))
        storefront.continuation.yield(.verified(transaction(id: 5, counter: sentinel)))
        await eventually { sentinel.calls == 1 }
        #expect(rejected.calls == 0)
        #expect(store.notice == nil)
        store.stopTransactionListener()
    }

    @Test func duplicateDeliveryFinishesOnceAndThanksOnlyForTheDirectPurchase() async {
        let storefront = Storefront()
        let counter = FinishCounter()
        let tip = transaction(counter: counter)
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        store.startTransactionListener()
        storefront.continuation.yield(.verified(tip))
        await eventually { counter.calls == 1 }
        #expect(store.notice == nil)
        storefront.purchaseResult = .transaction(.verified(tip))
        await store.purchase(TipStore.catalog[0])
        #expect(counter.calls == 1)
        #expect(store.notice?.kind == .thanks)
        store.dismissNotice()
        await store.purchase(TipStore.catalog[0])
        #expect(counter.calls == 1)
        #expect(store.notice == nil)
        store.stopTransactionListener()
    }

    @Test func transactionDeduplicationDoesNotBecomeAPermanentPurchaseHistory() async {
        let storefront = Storefront()
        let counter = FinishCounter()
        let store = TipStore(storefront: storefront)
        await store.loadProducts()
        // A bounded session window is enough for duplicate delivery without keeping all tips.
        for id in UInt64(1)...UInt64(130) {
            storefront.purchaseResult = .transaction(.verified(transaction(id: id, counter: counter)))
            await store.purchase(TipStore.catalog[0])
        }
        #expect(counter.calls == 130)
        storefront.purchaseResult = .transaction(.verified(transaction(id: 1, counter: counter)))
        await store.purchase(TipStore.catalog[0])
        #expect(counter.calls == 131)
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() { await Task.yield() }
        #expect(condition())
    }
}

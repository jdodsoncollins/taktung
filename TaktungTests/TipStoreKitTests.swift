import XCTest
import StoreKit
import StoreKitTest
import UIKit
@testable import Taktung

/// Local Xcode transactions only. These never contact a payment account or charge money.
@MainActor
final class TipStoreKitTests: XCTestCase {
    func testNativePricesRepeatTipsAndDeferredApproval() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        // Match the shipping UI's scene-aware StoreKit purchase. A context-free
        // product.purchase() can route to account sign-in even in the local test environment.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
        let action: TipPurchaseAction = { product in try await product.purchase(confirmIn: scene) }
        let store = TipStore()
        await store.loadProducts()
        XCTAssertNil(store.loadError)
        XCTAssertEqual(TipStore.catalog.compactMap { store.productsByID[$0.id]?.displayPrice },
                       ["$0.99", "$1.99", "$2.99", "$3.99", "$4.99"])
        await store.purchase(TipStore.catalog[0], using: action)
        XCTAssertEqual(store.notice?.kind, .thanks)
        store.dismissNotice()
        await store.purchase(TipStore.catalog[0], using: action)
        XCTAssertEqual(store.notice?.kind, .thanks)
        XCTAssertEqual(session.allTransactions().filter { $0.productIdentifier == "com.jcollins.takt.tip.kind" }.count, 2)

        session.askToBuyEnabled = true
        store.startTransactionListener()
        defer { store.stopTransactionListener() }
        await store.purchase(TipStore.catalog[2], using: action)
        XCTAssertEqual(store.notice?.kind, .pending)
        let pending = try XCTUnwrap(session.allTransactions().first(where: { $0.pendingAskToBuyConfirmation }))
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let deadline = ContinuousClock.now.advanced(by: .seconds(8))
        while store.notice != nil && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(store.notice)
        XCTAssertNil(store.purchasingID)
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TipJar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        return session
    }
}

import XCTest
import StoreKitTest
import UIKit

@MainActor
final class TipJarUITests: XCTestCase {
    func testTipMenuPricesRepeatPurchaseAndBackNavigation() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = openTipJar()
        let ids = ["kind", "thoughtful", "wonderful", "incredible", "extraordinary"]
        let prices = ["$0.99", "$1.99", "$2.99", "$3.99", "$4.99"]
        for (id, price) in zip(ids, prices) {
            let row = app.buttons["tips.com.jcollins.takt.tip.\(id)"]
            reveal(row, in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 8))
            XCTAssertTrue(row.label.contains(price))
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        }
        attach(app, name: "Tip-jar-standard")
        let first = app.buttons["tips.com.jcollins.takt.tip.kind"]
        reveal(first, in: app)
        waitUntilEnabled(first)
        first.tap()
        let thanks = app.alerts["Thank you"]
        XCTAssertTrue(thanks.waitForExistence(timeout: 8))
        thanks.buttons["OK"].tap()
        first.tap()
        XCTAssertTrue(thanks.waitForExistence(timeout: 8))
        thanks.buttons["OK"].tap()
        XCTAssertEqual(session.allTransactions().filter { $0.productIdentifier == "com.jcollins.takt.tip.kind" }.count, 2)
        // Duo moves the native Back control into its side toolbar.
        let back = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testTipMenuAtLargestTextSize() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = openTipJar(largestText: true)
        for id in ["kind", "thoughtful", "wonderful", "incredible", "extraordinary"] {
            let row = app.buttons["tips.com.jcollins.takt.tip.\(id)"]
            reveal(row, in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 8))
            XCTAssertTrue(row.isHittable)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
            XCTAssertGreaterThanOrEqual(row.frame.minX, 0)
            XCTAssertLessThanOrEqual(row.frame.maxX, app.windows.firstMatch.frame.maxX)
        }
        attach(app, name: "Tip-jar-largest-text")
    }

    func testCancellingNativeCheckoutLeavesTheMenuUsable() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.disableDialogs = false
        let app = openTipJar()
        let first = app.buttons["tips.com.jcollins.takt.tip.kind"]
        reveal(first, in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: first)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        first.tap()
        var cancel = app.buttons["Cancel"].firstMatch
        if !cancel.waitForExistence(timeout: 15) {
            let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            cancel = system.buttons["dismiss"].firstMatch
        }
        attach(app, name: "Tip-jar-native-confirmation")
        XCTAssertTrue(cancel.waitForExistence(timeout: 15))
        cancel.tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: first)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        XCTAssertFalse(app.alerts["Thank you"].exists)
        XCTAssertTrue(session.allTransactions().isEmpty)
        attach(app, name: "Tip-jar-after-cancellation")
    }

    func testTipMenuInLandscape() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = openTipJar()
        defer { XCUIDevice.shared.orientation = .portrait }
        let window = app.windows.firstMatch
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitForGeometry(window, landscape: false))
        attach(app, name: "Tip-jar-before-rotation")
        var landscapeReached = false
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            landscapeReached = waitForGeometry(window, landscape: true)
            attach(app, name: "Tip-jar-rotation-\(orientation.rawValue)")
            if landscapeReached { break }
        }
        XCTAssertTrue(landscapeReached, "The app window did not rotate into landscape: \(window.frame).")
        let ids = ["kind", "thoughtful", "wonderful", "incredible", "extraordinary"]
        let prices = ["$0.99", "$1.99", "$2.99", "$3.99", "$4.99"]
        for (id, price) in zip(ids, prices) {
            let row = app.buttons["tips.com.jcollins.takt.tip.\(id)"]
            reveal(row, in: app)
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: row)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
            XCTAssertTrue(row.label.contains(price))
            XCTAssertTrue(row.isHittable)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
            XCTAssertGreaterThanOrEqual(row.frame.minX, window.frame.minX)
            XCTAssertLessThanOrEqual(row.frame.maxX, window.frame.maxX)
        }
        attach(app, name: "Tip-jar-landscape")
    }

    func testDarkTipMenuAndOtherAppsNavigation() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = openTipJar(appearance: "dark")
        let first = app.buttons["tips.com.jcollins.takt.tip.kind"]
        reveal(first, in: app)
        waitUntilEnabled(first)
        attach(app, name: "Tip-jar-dark")
        // Duo's side toolbar exposes the native identifier without a title label.
        let back = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.isHittable)
        back.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let apps = app.descendants(matching: .any)["takt.settings.otherApps"].firstMatch
        reveal(apps, in: app)
        apps.tap()
        XCTAssertTrue(app.navigationBars["Other Apps"].waitForExistence(timeout: 5))
        for name in ["Codable", "TabForge", "Paper & Grain"] {
            let title = app.staticTexts[name].firstMatch
            reveal(title, in: app)
            XCTAssertTrue(title.isHittable)
        }
        attach(app, name: "Other-apps-dark")
    }

    private func makeSession() throws -> SKTestSession {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TipJar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        return session
    }

    private func openTipJar(largestText: Bool = false, appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-TAKT_DEMO_MODE", "-taktung.appearance", appearance]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let settings = app.buttons["takt.tab.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let link = app.descendants(matching: .any)["takt.settings.tipJar"].firstMatch
        reveal(link, in: app)
        link.tap()
        XCTAssertTrue(app.navigationBars["Tip Jar"].waitForExistence(timeout: 5))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let scroller = app.collectionViews.firstMatch
        for _ in 0..<30 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.minY < scroller.frame.minY {
                scroller.swipeDown()
            } else {
                scroller.swipeUp()
            }
        }
        XCTFail("The tip menu control could not be reached.")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        // App-scoped capture can crop against stale portrait coordinates just
        // after rotation. Preserve the complete display and its AX geometry.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func waitUntilEnabled(_ element: XCUIElement) {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 8), .completed)
    }

    private func waitForGeometry(_ window: XCUIElement, landscape: Bool) -> Bool {
        let geometry = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                landscape ? window.frame.width > window.frame.height : window.frame.height > window.frame.width
            }, object: nil
        )
        return XCTWaiter.wait(for: [geometry], timeout: 8) == .completed
    }
}

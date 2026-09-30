import Foundation
import StoreKitTest
import XCTest

@testable import LogicCasebookUI

/// Exercises the ¥1,800 non-consumable "unlock everything" entitlement
/// (docs/logic-casebook-locked-process-flow.md, sections 2 and 4.8) against
/// a local StoreKit Testing configuration. `SKTestSession` is Apple's own
/// supported way to run real StoreKit 2 APIs in an automated test, without a
/// real App Store sandbox account -- which this environment has no way to
/// sign into or approve dialogs for.
///
/// `Product.purchase()`'s UI-anchored confirmation flow needs a foreground
/// window scene this headless unit-test bundle doesn't have, so that call is
/// covered only by manual simulator testing (`ios/README.md`).
///
/// The purchase, restore and revocation rules are tested in
/// `EntitlementLogicTests` against a fake `EntitlementBackend`: the real
/// `Transaction.currentEntitlements` hangs against StoreKitTest's local
/// daemon on GitHub-hosted runners ("AMSErrorDomain Code=301" on its
/// transaction-history endpoint), so those rules cannot be exercised through
/// live StoreKit in CI. This file keeps only what does work there -- loading
/// the product from the StoreKit configuration.
final class EntitlementStoreTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        // `SKTestSession(configurationFileNamed:)` failed in CI with
        // "File not found": SwiftPM copies test-target resources into a
        // nested "LogicCasebook_LogicCasebookUITests.bundle" inside the
        // .xctest bundle rather than its root, and that lookup doesn't find
        // resources there. `Bundle.module` (which SwiftPM generates for any
        // target that declares `resources:`) does, so go straight to a URL.
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Configuration", withExtension: "storekit"),
            "Configuration.storekit not found in Bundle.module"
        )
        session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDownWithError() throws {
        // Optional chaining, not `session.clearTransactions()`: if setUp
        // ever fails before assigning `session`, tearDown force-unwrapping
        // it too turns one reported test failure into a process crash that
        // takes the rest of the test run down with it (as happened here).
        session?.clearTransactions()
    }

    @MainActor
    func testProductLoads() async throws {
        let store = EntitlementStore()
        await store.refreshProducts()

        let product = try XCTUnwrap(store.fullUnlockProduct)
        XCTAssertEqual(product.id, EntitlementStore.fullUnlockProductID)
        XCTAssertFalse(store.isFullUnlockPurchased)
    }
}

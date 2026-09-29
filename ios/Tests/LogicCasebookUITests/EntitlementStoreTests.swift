import Foundation
import StoreKitTest
import XCTest

@testable import LogicCasebookUI

/// Exercises the ¥1,800 non-consumable "unlock everything" entitlement
/// (docs/logic-casebook-locked-process-flow.md, sections 2 and 4.8) against
/// a local StoreKit Testing configuration. `SKTestSession` is Apple's own
/// supported way to run purchase/restore through real StoreKit 2 APIs in an
/// automated test, without a real App Store sandbox account -- which this
/// environment has no way to sign into or approve dialogs for.
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

    @MainActor
    func testPurchaseUnlocksEntitlement() async throws {
        let store = EntitlementStore()
        await store.start()
        XCTAssertFalse(store.isFullUnlockPurchased)

        await store.purchaseFullUnlock()

        XCTAssertTrue(store.isFullUnlockPurchased)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testRestorePurchasesRecoversEntitlementOnAFreshStore() async throws {
        let purchasing = EntitlementStore()
        await purchasing.start()
        await purchasing.purchaseFullUnlock()
        XCTAssertTrue(purchasing.isFullUnlockPurchased)

        // A second EntitlementStore instance -- standing in for a fresh
        // install or a signed-out/signed-in device -- starts locked...
        let restoring = EntitlementStore()
        await restoring.refreshProducts()
        XCTAssertFalse(restoring.isFullUnlockPurchased)

        // ...and Restore Purchases (section 4.8, step 4) recovers it.
        await restoring.restorePurchases()
        XCTAssertTrue(restoring.isFullUnlockPurchased)
    }
}

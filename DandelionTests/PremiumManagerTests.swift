//
//  PremiumManagerTests.swift
//  DandelionTests
//
//  Unit tests for PremiumManager purchase flow
//

import XCTest
@testable import Dandelion

@MainActor
final class PremiumManagerTests: XCTestCase {
    func testPurchaseLoadsProductAndAttemptsPurchase() async {
        let stubProduct = StubProduct()
        var loadCalls = 0
        let sut = PremiumManager(
            productLoader: { _ in
                loadCalls += 1
                return [stubProduct]
            },
            shouldRefreshOnInit: false,
            shouldObserveTransactions: false
        )

        XCTAssertNil(sut.product, "Product should start nil")

        await sut.purchase()

        XCTAssertEqual(loadCalls, 1, "Should load product once during purchase")
        XCTAssertEqual(stubProduct.purchaseCallCount, 1, "Should attempt purchase after loading product")
        XCTAssertNotNil(sut.product, "Product should be cached after purchase")
    }
}

@MainActor
private final class StubProduct: StoreProduct {
    var displayPrice: String = "$0.00"
    private(set) var purchaseCallCount: Int = 0
    var purchaseResult: StorePurchaseResult = .userCancelled

    func purchase() async throws -> StorePurchaseResult {
        purchaseCallCount += 1
        return purchaseResult
    }
}

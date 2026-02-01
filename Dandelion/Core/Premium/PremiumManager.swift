//
//  PremiumManager.swift
//  Dandelion
//
//  StoreKit 2 premium entitlement manager
//

import Foundation
import StoreKit

@MainActor
@Observable
final class PremiumManager {
    static let shared = PremiumManager()

    private let productID = "com.dandelion.bloom.premium"
    private let cacheKey = "com.dandelion.bloom.cachedEntitlement"
    #if DEBUG
    private let debugOverrideKey = "com.dandelion.bloom.debugOverride"
    private let debugForceLockedKey = "com.dandelion.bloom.debugForceLocked"
    #endif

    private(set) var product: (any StoreProduct)?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var cachedEntitlement: Bool = false
    #if DEBUG
    var debugForceBloom: Bool = false {
        didSet {
            UserDefaults.standard.set(debugForceBloom, forKey: debugOverrideKey)
        }
    }
    var debugForceBloomLocked: Bool = false {
        didSet {
            UserDefaults.standard.set(debugForceBloomLocked, forKey: debugForceLockedKey)
        }
    }
    #endif

    var isBloomUnlocked: Bool {
        #if DEBUG
        if debugForceBloomLocked { return false }
        if debugForceBloom { return true }
        #endif
        return cachedEntitlement
    }

    var priceDisplay: String {
        product?.displayPrice ?? "$4.99"
    }

    private var transactionUpdatesTask: Task<Void, Never>?
    private let productLoader: @MainActor ([String]) async throws -> [any StoreProduct]

    init(
        productLoader: @escaping @MainActor ([String]) async throws -> [any StoreProduct] = PremiumManager.defaultProductLoader,
        shouldRefreshOnInit: Bool = true,
        shouldObserveTransactions: Bool = true
    ) {
        self.productLoader = productLoader
        cachedEntitlement = UserDefaults.standard.bool(forKey: cacheKey)
        #if DEBUG
        debugForceBloom = UserDefaults.standard.bool(forKey: debugOverrideKey)
        debugForceBloomLocked = UserDefaults.standard.bool(forKey: debugForceLockedKey)
        #endif
        if shouldObserveTransactions {
            startObservingTransactions()
        }
        if shouldRefreshOnInit {
            Task {
                await refreshEntitlement()
            }
        }
    }


    func refreshEntitlement() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await loadProductIfNeeded()

            var hasEntitlement = false
            for await entitlement in Transaction.currentEntitlements {
                guard case .verified(let transaction) = entitlement else { continue }
                if transaction.productID == productID {
                    hasEntitlement = true
                    break
                }
            }

            updateCachedEntitlement(hasEntitlement)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await loadProductIfNeeded()
            guard let product else {
                errorMessage = "Unable to load product."
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let finish):
                await finish()
                updateCachedEntitlement(true)
                errorMessage = nil
            case .userCancelled:
                errorMessage = nil
            case .pending:
                errorMessage = "Purchase pending approval."
            case .verificationFailed:
                errorMessage = "Purchase verification failed."
            case .unknown:
                errorMessage = "Unknown purchase state."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateCachedEntitlement(_ newValue: Bool) {
        cachedEntitlement = newValue
        UserDefaults.standard.set(newValue, forKey: cacheKey)
    }

    private func loadProductIfNeeded() async throws {
        if product == nil {
            let products = try await productLoader([productID])
            product = products.first
        }
    }

    private func startObservingTransactions() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { @MainActor [weak self] in
            for await update in Transaction.updates {
                if Task.isCancelled { break }
                guard let self else { break }
                guard case .verified(let transaction) = update else { continue }
                guard transaction.productID == self.productID else { continue }
                let isEntitled = transaction.revocationDate == nil
                self.updateCachedEntitlement(isEntitled)
                await transaction.finish()
            }
        }
    }

    @MainActor
    private static func defaultProductLoader(ids: [String]) async throws -> [any StoreProduct] {
        let products = try await Product.products(for: ids)
        return products.map { StoreKitProduct(product: $0) }
    }
}

protocol StoreProduct {
    var displayPrice: String { get }
    func purchase() async throws -> StorePurchaseResult
}

enum StorePurchaseResult {
    case success(finish: @Sendable () async -> Void)
    case userCancelled
    case pending
    case verificationFailed
    case unknown
}

private struct StoreKitProduct: StoreProduct {
    let product: Product

    var displayPrice: String {
        product.displayPrice
    }

    func purchase() async throws -> StorePurchaseResult {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                return .success(finish: { await transaction.finish() })
            case .unverified:
                return .verificationFailed
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .unknown
        }
    }
}

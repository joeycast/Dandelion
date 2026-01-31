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

    private(set) var product: Product?
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

    private init() {
        cachedEntitlement = UserDefaults.standard.bool(forKey: cacheKey)
        #if DEBUG
        debugForceBloom = UserDefaults.standard.bool(forKey: debugOverrideKey)
        debugForceBloomLocked = UserDefaults.standard.bool(forKey: debugForceLockedKey)
        #endif
        Task {
            await refreshEntitlement()
        }
    }

    func refreshEntitlement() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if product == nil {
                let products = try await Product.products(for: [productID])
                product = products.first
            }

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
        guard let product else {
            await refreshEntitlement()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "Purchase verification failed."
                    return
                }
                await transaction.finish()
                updateCachedEntitlement(true)
                errorMessage = nil
            case .userCancelled:
                errorMessage = nil
            case .pending:
                errorMessage = "Purchase pending approval."
            @unknown default:
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
}

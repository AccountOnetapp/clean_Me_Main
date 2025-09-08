import StoreKit
import ApphudSDK
import Combine

enum PurchaseServiceProduct: String {
    case week = "test.cleanme.week" // todo - use real
    case month = "" //  - не используем в текущем релизе никак
}

enum PurchaseServiceResult {
    case success
    case failure(Error?)
}

// MARK: - SKProduct Extension for Localization
public extension SKProduct {
    var localizedPrice: String? {
        // Updated to use a helper method for clarity
        return PriceFormatter.formatter(for: Locale.current).string(from: price)
    }
    
    var currency: String {
        return PriceFormatter.formatter(for: Locale.current).currencySymbol
    }

    private struct PriceFormatter {
        static func formatter(for locale: Locale) -> NumberFormatter {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            return formatter
        }
    }
}

// MARK: - ApphudPurchaseService: Manages all Apphud-related transactions
final class ApphudPurchaseService {
    
    // Custom errors for purchase flow
    enum PurchaseError: Error {
        case cancelled
        case noProductsFound
        case productNotFound(String)
        case purchaseFailed
        case noActiveSubscription
    }
    
    // Typealias for clarity in method signatures
    typealias PurchaseCompletion = (PurchaseServiceResult) -> Void
    
    // MARK: - Properties
    
    // Store fetched Apphud products
    private var availableProducts: [ApphudProduct] = []

    // Public property to check subscription status
    var hasActiveSubscription: Bool {
        Apphud.hasActiveSubscription()
    }
    
    // MARK: - Initialization
    
    // Init is now async to handle product fetching
    init() {
        Task {
            await fetchProducts()
        }
    }
    
    // MARK: - Public Methods
    
    /// Purchases a subscription plan.
    @MainActor
    func purchase(plan: SubscriptionPlan, completion: @escaping PurchaseCompletion) {
        let identifier: String
        switch plan {
        case .monthly:
            identifier = PurchaseServiceProduct.month.rawValue
        case .weekly:
            identifier = PurchaseServiceProduct.week.rawValue
        }
        
        guard let product = availableProducts.first(where: { $0.productId == identifier }) else {
            completion(.failure(PurchaseError.productNotFound(identifier)))
            return
        }

        Apphud.purchase(product) { result in
            if let error = result.error {
                print("Apphud: Purchase failed with error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let subscription = result.subscription, subscription.isActive() {
                print("Apphud: Purchase success - subscription is active.")
                completion(.success)
            } else if result.nonRenewingPurchase != nil {
                print("Apphud: Purchase success - non-renewing purchase.")
                completion(.success)
            } else {
                print("Apphud: Purchase failed - unknown reason.")
                completion(.failure(PurchaseError.purchaseFailed))
            }
        }
    }
    
    /// Restores all purchases for the user.
    @MainActor
    func restore(completion: @escaping PurchaseCompletion) {
        Apphud.restorePurchases { subscriptions, nonRenewingPurchases, error in
            if let restoreError = error {
                completion(.failure(restoreError))
                return
            }
            
            if subscriptions?.first(where: { $0.isActive() }) != nil {
                print("Apphud: Restore successful - active subscription found.")
                completion(.success)
            } else {
                print("Apphud: Restore completed, but no active subscription found.")
                completion(.failure(PurchaseError.noActiveSubscription))
            }
        }
    }
    
    /// Returns the numerical price for a given product.
    func price(for product: PurchaseServiceProduct) -> Double? {
        guard let apphudProduct = availableProducts.first(where: { $0.productId == product.rawValue }),
              let skProduct = apphudProduct.skProduct else {
            return nil
        }
        return skProduct.price.doubleValue
    }
    
    /// Returns the localized price string for a given product.
    func localizedPrice(for product: PurchaseServiceProduct) -> String? {
        guard let apphudProduct = availableProducts.first(where: { $0.productId == product.rawValue }),
              let skProduct = apphudProduct.skProduct else {
            // Fallback for when Apphud products are not available
            return product == .month ? "$18.99" : "$6.99"
        }
        return skProduct.localizedPrice
    }
    
    /// Returns the currency symbol for a given product.
    func currency(for product: PurchaseServiceProduct) -> String? {
        guard let apphudProduct = availableProducts.first(where: { $0.productId == product.rawValue }),
              let skProduct = apphudProduct.skProduct else {
            return nil
        }
        return skProduct.currency
    }

    /// Calculates and returns the per-day price string.
    func perDayPrice(for product: PurchaseServiceProduct) -> String {
        guard let priceValue = price(for: product),
              let currencySymbol = currency(for: product) else {
            // Fallback price
            return "$1.28"
        }
        
        let perDay: Double
        if product == .week {
            perDay = priceValue / 7
        } else {
            perDay = priceValue / 30
        }
        
        // Formats the string with 2 decimal places
        return String(format: "%.2f%@", perDay, currencySymbol)
    }

    // MARK: - Private Methods
    
    /// Asynchronously fetches Apphud products from the paywalls.
    private func fetchProducts() async {
        let placements = await Apphud.placements(maxAttempts: 3)
        guard let paywall = placements.first?.paywall, !paywall.products.isEmpty else {
            print("Apphud: No products found on paywall.")
            return
        }
        
        self.availableProducts = paywall.products
        print("Apphud: Fetched products with IDs: \(self.availableProducts.map { $0.productId })")
    }
}

import StoreKit
import ApphudSDK
import Combine

enum PurchaseServiceProduct: String {
    case week = "cleanme.week"
    case month = "cleanme.month"
}

enum PurchaseServiceResult {
    case success
    case failure(Error?)
}

public extension SKProduct {
    var localizedPrice: String? {
        return priceFormatter(locale: Locale.current).string(from: price)
    }
    
    var currency: String {
        return priceFormatter(locale: Locale.current).currencySymbol
    }

    private func priceFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        return formatter
    }
}

final class ApphudPurchaseService {
    
    enum CustomError: Error {
        case cancelled
        case emptyList
        case notFullList
        case noSuchProduct
        case unknownError
        case noActiveSubscription
    }
    
    // Используем ApphudProduct напрямую для работы
    private var apphudProducts: [ApphudProduct] = []

    var hasActiveSubscription: Bool {
        Apphud.hasActiveSubscription()
    }
    
    init() {
        getProducts()
    }
    
    func getProducts() {
        Task {
            let placements = await Apphud.placements(maxAttempts: 3)
            if let placement = placements.first, let paywall = placement.paywall, !paywall.products.isEmpty {
                self.apphudProducts = paywall.products
                print("fetched products for IDs: \(self.apphudProducts.map { $0.productId })")
            } else {
                self.apphudProducts = []
            }
        }
    }
    
    @MainActor
    func purchase(with plan: SubscriptionPlan, closure: @escaping (PurchaseServiceResult) -> Void) {
        let productID: String
        switch plan {
        case .monthly:
            productID = PurchaseServiceProduct.month.rawValue
        case .weekly:
            productID = PurchaseServiceProduct.week.rawValue
        }

        guard let apphudProduct = apphudProducts.first(where: { $0.productId == productID }) else {
            closure(.failure(CustomError.noSuchProduct))
            return
        }

        Apphud.purchase(apphudProduct) { result in
            if result.error != nil {
                closure(.failure(result.error))
                return
            }

            if let subscription = result.subscription, subscription.isActive() {
                print("Apphud: Purchase success - subscription is active.")
                closure(.success)
            } else if result.nonRenewingPurchase != nil {
                print("Apphud: Purchase success - non-renewing purchase.")
                closure(.success)
            } else {
                print("Apphud: Purchase failed - unknown reason.")
                closure(.failure(CustomError.unknownError))
            }
        }
    }
    
    @MainActor
    func restore(closure: @escaping (PurchaseServiceResult) -> Void) {
        Apphud.restorePurchases { subscriptions, nonRenewingPurchases, error in
            if let error = error {
                closure(.failure(error))
                return
            }

            let hasActiveSubscription = subscriptions?.first(where: { $0.isActive() }) != nil
            
            if hasActiveSubscription {
                print("Apphud: Restore successful - active subscription found.")
                closure(.success)
            } else {
                print("Apphud: Restore completed, but no active subscription found.")
                closure(.failure(CustomError.noActiveSubscription))
            }
        }
    }
    
    func price(for product: PurchaseServiceProduct) -> Double? {
        guard let apphudProduct = apphudProducts.first(where: { $0.productId == product.rawValue }),
              let skProduct = apphudProduct.skProduct else {
            return nil
        }
        return skProduct.price.doubleValue
    }
    
    func localizedPrice(for product: PurchaseServiceProduct) -> String? {
        guard let apphudProduct = apphudProducts.first(where: { $0.productId == product.rawValue }),
              let skProduct = apphudProduct.skProduct else {
            return product == .month ? "$18.99" : "$6.99"
        }
        return skProduct.localizedPrice
    }
    
    func currency(for product: PurchaseServiceProduct) -> String? {
        guard let apphudProduct = apphudProducts.first(where: { $0.productId == product.rawValue }),
              let skProduct = apphudProduct.skProduct else {
            return nil
        }
        return skProduct.currency
    }

    func perDayPrice(for product: PurchaseServiceProduct) -> String {
        guard let price = price(for: product),
              let currencySymbol = currency(for: product) else {
            return "$1.28"
        }
        
        switch product {
        case .week:
            return String(format: "%.2f%@", price / 7, currencySymbol)
        case .month:
            return String(format: "%.2f%@", price / 30, currencySymbol)
        }
    }
}

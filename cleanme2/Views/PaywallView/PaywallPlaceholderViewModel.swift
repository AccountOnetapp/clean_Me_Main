import SwiftUI
import Combine

final class PaywallViewModel: ObservableObject {
    private let purchaseService = ApphudPurchaseService()
    private let isPresented: Binding<Bool>

    @Published var weekPrice: String = "N/A"
    @Published var monthPrice: String = "N/A"
    @Published var weekPricePerDay: String = "N/A"
    @Published var monthPricePerDay: String = "N/A"
    
    init(isPresented: Binding<Bool>) {
        self.isPresented = isPresented
        
        Task {
            await loadProducts()
        }
    }
    
    private func loadProducts() async {        
        await MainActor.run {
            self.weekPrice = purchaseService.localizedPrice(for: .week) ?? "N/A"
            self.monthPrice = purchaseService.localizedPrice(for: .month) ?? "N/A"
            self.weekPricePerDay = purchaseService.perDayPrice(for: .week)
            self.monthPricePerDay = purchaseService.perDayPrice(for: .month)
        }
    }
    
    @MainActor
    func continueTapped(with plan: SubscriptionPlan) {
        purchaseService.purchase(with: plan) { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error purchasing: \(error?.localizedDescription ?? "Unknown error")")
                return
            case .success:
                self?.closePaywall()
            }
        }
    }
    
    @MainActor
    func restoreTapped() {
        purchaseService.restore() { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error purchasing: \(error?.localizedDescription ?? "Unknown error")")
                self?.closePaywall()
                return
            case .success:
                self?.closePaywall()
            }
        }
    }
    
    private func closePaywall() {
        isPresented.wrappedValue = false
    }
}

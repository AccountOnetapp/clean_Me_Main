import SwiftUI
import Combine
import SafariServices
import StoreKit

// Структура для данных онбординг-экрана
struct OnboardingScreen: Identifiable {
    let id = UUID()
    let title: String
    let highlightedPart: String
    let subtitle: String
    let imageName: String?
    let isLastScreen: Bool // Добавляем флаг для последнего экрана
}

final class OnboardingViewModel: ObservableObject {
    let screens: [OnboardingScreen] = [
        OnboardingScreen(
            title: "Save files in a secret folder",
            highlightedPart: "secret folder",
            subtitle: "Hide important photos, videos, documents and contacts from third person. 100% security",
            imageName: "onboarding1",
            isLastScreen: false
        ),
        OnboardingScreen(
            title: "Check your internet speed",
            highlightedPart: "internet speed",
            subtitle: "Compare your actual speed with what your provider promises",
            imageName: "onboarding2",
            isLastScreen: false
        ),
        OnboardingScreen(
            title: "Clean your gallery",
            highlightedPart: "Clean",
            subtitle: "Quickly find the same photos and remove them in one tap",
            imageName: "onboarding3",
            isLastScreen: true
        )
    ]
    
    func licenseAgreementTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.licenseAgreementURL) else { return }
        UIApplication.shared.open(url)
    }
    
    func privacyPolicyTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.privacyPolicyURL) else { return }
        UIApplication.shared.open(url)
    }
 
    @MainActor
    func restoreTapped() {
        let purchaseService = ApphudPurchaseService()

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
        // do nothing
    }
}

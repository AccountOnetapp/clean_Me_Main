import SwiftUI
import Combine
import SafariServices
import StoreKit

enum ResurcesUrlsConstants {
    // todo Замените эти URL на реальные
    static let licenseAgreementURL: String = "https://docs.google.com/document/d/1OwaR-nw8bOiLE0QM2t7mgsZhH_piBTMcfOrvcov3a8M/edit?usp=sharing"
    static let privacyPolicyURL: String = "https://docs.google.com/document/d/1ODflJsIb9M4ciQiYU6ZWQZ1ETMbvjW6-ifpNjVzgUSE/edit?usp=sharing"
    static let termsURL: String = "https://docs.google.com/document/d/1OwaR-nw8bOiLE0QM2t7mgsZhH_piBTMcfOrvcov3a8M/edit?usp=sharing"
    static let feedBackEmail: String = "feedback@yourapp.com"
}

final class SettingsViewModel: ObservableObject {
    
    @Published var isPasscodeEnabledInApp: Bool = false {
        didSet {
            // MARK: - Обработка изменения состояния переключателя
            print("isPasscodeEnabledInApp changed to: \(isPasscodeEnabledInApp)")
        }
    }
    
    @Published var isFaceIDInAppEnabled: Bool = false {
        didSet {
            // MARK: - Обработка изменения состояния переключателя
            print("isFaceIDInAppEnabled changed to: \(isFaceIDInAppEnabled)")
        }
    }
    
    @Published var isSecretSpacePasscodeEnabled: Bool = true {
        didSet {
            // MARK: - Обработка изменения состояния переключателя
            print("isSecretSpacePasscodeEnabled changed to: \(isSecretSpacePasscodeEnabled)")
        }
    }
    
    @Published var isSecretSpaceFaceIDEnabled: Bool = true {
        didSet {
            // MARK: - Обработка изменения состояния переключателя
            print("isSecretSpaceFaceIDEnabled changed to: \(isSecretSpaceFaceIDEnabled)")
        }
    }
    
    init() {
        // Здесь можно загрузить начальные значения из UserDefaults
        // Например: isPasscodeEnabledInApp = UserDefaults.standard.bool(forKey: "passcodeEnabled")
    }
    
    func rateUsTapped() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func licenseAgreementTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.licenseAgreementURL) else { return }
        UIApplication.shared.open(url)
    }
    
    func privacyPolicyTapped() {
        guard let url = URL(string: ResurcesUrlsConstants.privacyPolicyURL) else { return }
        UIApplication.shared.open(url)
    }
    
    func sendFeedbackTapped() {
        // MARK: - Открытие почтового клиента с предзаполненным письмом
        let subject = "Feedback"
        let body = "" // Можно добавить текст по умолчанию
        let mailtoString = "mailto:\(ResurcesUrlsConstants.feedBackEmail)?subject=\(subject)&body=\(body)"
        
        if let mailtoUrl = URL(string: mailtoString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            UIApplication.shared.open(mailtoUrl)
        }
    }
}

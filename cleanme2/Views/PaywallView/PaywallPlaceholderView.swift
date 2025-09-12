//
//  PaywallPlaceholderView.swift
//  cleanme2
//

import SwiftUI

enum SubscriptionPlan {
    case weekly
    case monthly3
    case yearly
}

// MARK: - PaywallView
struct PaywallView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: PaywallViewModel

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: PaywallViewModel(isPresented: isPresented))
    }

    var body: some View {
        ZStack {
            // Фон
            CMColor.background
                .ignoresSafeArea()
            
            // Основной контент
            VStack(spacing: 0) {
                
                // Заголовок
                PaywallHeaderView()
                    .padding(.top, 20)
                
                // Блок с иконками и ГБ
                PaywallIconsBlockView()
                    .padding(.top, 20)
                
                // Блок с "таблетками"
                PaywallFeaturesTagView()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Текст о бесплатности и цене
                VStack(spacing: 8) {
                    Text("100% FREE FOR 3 DAYS")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                    
                    Text("ZERO FEE WITH RISK FREE\nNO EXTRA COST")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Текст с ценой и отменой
                Text("Try 3 days free, after $6.99/week\nCancel anytime")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                Spacer()
                
                // Кнопка "Continue"
                PaywallContinueButton(action: {
                    viewModel.continueTapped(with: .weekly)
                })
                .padding(.horizontal, 20)
                
                // Нижние ссылки
                PaywallBottomLinksView(isPresented: $isPresented, viewModel: viewModel)
                    .padding(.vertical, 10)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Компоненты

struct PaywallHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Premium Free")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(CMColor.primary)
            
            Text("for 3 days")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
        }
    }
}

struct PaywallIconsBlockView: View {
    var body: some View {
        HStack(spacing: 20) {
            IconWithText(imageName: "PayWallImege1", text: "16.4 Gb")
            IconWithText(imageName: "PayWallImege2", text: "2.5 Gb")
            IconWithText(imageName: "PayWallImege3", text: "0.2 Gb")
        }
    }
}

struct IconWithText: View {
    let imageName: String
    let text: String
    
    // Определяем размер иконки
    var iconSize: CGFloat {
        return 100
    }
        
    var body: some View {
        VStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(CMColor.iconPrimary)
            
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
        }
    }
}

struct PaywallFeaturesTagView: View {
    let features = [
        "Keep your contacts and media in a Secret folder",
        "Internet speed check",
        "Ad-free",
        "Easy cleaning of the gallery and contacts",
        "Complete info about your phone"
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            FeatureTagView(text: features[0])
            
            HStack(spacing: 12) {
                FeatureTagView(text: features[1])
                FeatureTagView(text: features[2])
            }
            
            FeatureTagView(text: features[3])
            FeatureTagView(text: features[4])
        }
    }
}

private struct FeatureTagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(CMColor.backgroundSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(CMColor.primary, lineWidth: 1)
            )
            .foregroundColor(CMColor.primary)
    }
}

// Кнопка "Continue"
struct PaywallContinueButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CMColor.activeButton)
                .clipShape(Capsule())
        }
    }
}

struct PaywallBottomLinksView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: PaywallViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            Button("Privacy Policy") {
                viewModel.privacyPolicyTapped()
            }
            
            Button("Restore") {
                viewModel.restoreTapped()
            }
            
            Button("Terms of Use") {
                viewModel.licenseAgreementTapped()
            }
            
            Button("Skip") {
                isPresented = false
            }
        }
        .font(.system(size: 12))
        .foregroundColor(CMColor.secondaryText)
    }
}

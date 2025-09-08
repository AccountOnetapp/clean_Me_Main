//
//  PaywallPlaceholderView.swift
//  cleanme2
//

import SwiftUI

enum SubscriptionPlan {
    case weekly, monthly
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
            Color.white
                .ignoresSafeArea()
            
            // Основной контент
            VStack(spacing: 0) {
                
                // Заголовок
                PaywallHeaderView()
                    .padding(.top, 20)
                
                // Блок с иконками и ГБ
                PaywallIconsBlockView()
                    .padding(.top, 40)
                
                // Блок с "таблетками"
                PaywallFeaturesTagView()
                    .padding(.horizontal, 20)
                    .padding(.top, 30)

                // Текст о бесплатности и цене
                VStack(spacing: 8) {
                    Text("100% FREE FOR 3 DAYS")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2)) // Примерный цвет
                    
                    Text("ZERO FEE WITH RISK FREE\nNO EXTRA COST")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Текст с ценой и отменой
                Text("Try 3 days free, after $6.99/week\nCancel anytime")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                Spacer()
                
                // Кнопка "Continue"
                PaywallContinueButton(action: {
//                    viewModel.continueTapped()
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

// Заголовок
struct PaywallHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Premium Free")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            
            Text("for 3 days")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
        }
    }
}

// Блок с иконками
struct PaywallIconsBlockView: View {
    var body: some View {
        HStack(spacing: 40) {
            IconWithText(imageName: "folder.fill.badge.plus", text: "16.4 Gb")
            IconWithText(imageName: "folder.fill", text: "2.5 Gb")
            IconWithText(imageName: "doc.text.fill", text: "0.2 Gb")
        }
    }
}

// Компонент для иконки с текстом
struct IconWithText: View {
    let imageName: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(Color.gray.opacity(0.8)) // Замените на нужный цвет
            
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}

// "Таблетки" с функциями
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
            ForEach(features, id: \.self) { feature in
                Text(feature)
                    .font(.system(size: 15, weight: .regular))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
        }
    }
}

// Кнопка "Continue"
struct PaywallContinueButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.blue]), // Замените на ваши цвета градиента
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// Нижние ссылки
struct PaywallBottomLinksView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: PaywallViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            Button("Privacy Policy") {
//                viewModel.pr()
            }
            
            Button("Restore") {
                viewModel.restoreTapped()
            }
            
            Button("Terms of Use") {
//                viewModel.termsOfUseTapped()
            }
            
            Button("Skip") {
                isPresented = false
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
}

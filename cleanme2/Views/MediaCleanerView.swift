//
//  MediaCleanerView.swift
//  cleanme2
//
//  Created by AI Assistant on 10.08.25.
//

import SwiftUI

// Main View
struct MediaCleanerView: View {
    @StateObject private var viewModel = MediaCleanerViewModel()
    @State private var isTabBarVisible: Bool = true // State variable for tab bar visibility
    @State private var isPasswordSet: Bool = false // Track if password is set
    @State private var isSafeFolderUnlocked: Bool = false // Track if safe folder is currently unlocked
    @State private var isPaywallPresented: Bool = false // New state variable for presenting the paywall

    @AppStorage("paywallShown") var paywallShown: Bool = false

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }

    var body: some View {
        ZStack {
            // Фон
            CMColor.background
                .ignoresSafeArea()
            
            if paywallShown {
                VStack(spacing: 0) {
                    switch viewModel.selectedTab {
                    case .clean:
                        ScanView(isPaywallPresented: $isPaywallPresented)
                    case .dashboard:
                        SpeedTestView(isPaywallPresented: $isPaywallPresented)
                    case .star:
                        SmartCleanView(isPaywallPresented: $isPaywallPresented)
                    case .safeFolder:
                        safeFolder
                    case .settings:
                        SettingsView(isPaywallPresented: $isPaywallPresented)
                    }
                }
                .onChange(of: viewModel.selectedTab) { newValue in
                    // Reset safe folder authentication when switching away from safe tab
                    if newValue != .safeFolder {
                        isSafeFolderUnlocked = false
                    }
                }
                
                // Плавающая панель вкладок
                if isTabBarVisible {
                    VStack {
                        Spacer()
                        
                        CustomTabBar(selectedTab: $viewModel.selectedTab)
                            .padding(.bottom, 16 * scalingFactor)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView(isPresented: $isPaywallPresented)
                .onDisappear {
                    paywallShown = true
                }
        }
        .onAppear {
            if !paywallShown {
                isPaywallPresented = true
            }
        }
    }
    
    // MARK: - Новый экран: Safe Folder
    private var safeFolder: some View {
        Group {
            if !isSafeFolderUnlocked {
                PasswordCodeView(
                    onTabBarVisibilityChange: { isVisible in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isTabBarVisible = isVisible
                        }
                    },
                    onCodeEntered: { code in
                        // Handle successful PIN entry
                        print("PIN entered: \(code)")
                        // Unlock the safe folder for this session
                        isSafeFolderUnlocked = true
                    },
                    onBackButtonTapped: {
                        viewModel.selectedTab = .clean
                    },
                    shouldAutoDismiss: false
                )
            } else {
                // Safe folder content when authenticated
                SafeStorageView(isPaywallPresented: $isPaywallPresented)
            }
        }
        .onAppear {
            checkPasswordStatus()
        }
    }
    
    // MARK: - Helper Methods
    private func checkPasswordStatus() {
        let savedPin = UserDefaults.standard.string(forKey: "safe_storage_pin")
        isPasswordSet = savedPin != nil && !savedPin!.isEmpty
    }
}

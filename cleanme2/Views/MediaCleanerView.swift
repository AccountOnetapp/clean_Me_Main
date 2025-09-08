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

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }

    var body: some View {
        ZStack {
            // Фон
            CMColor.background
                .ignoresSafeArea()

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
            .fullScreenCover(isPresented: $isPaywallPresented) {
                PaywallView(isPresented: $isPaywallPresented)
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
        .onAppear {
//            if case .idle = viewModel.scanningState, viewModel.mediaCategories.isEmpty {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    viewModel.startScanning()
//                }
//            }
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
                SafeStorageView()
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

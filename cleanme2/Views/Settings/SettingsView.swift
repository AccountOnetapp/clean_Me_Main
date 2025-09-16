//
//  SettingsView.swift
//  cleanme2
//

import SwiftUI

struct SettingsView: View {
    @Binding var isPaywallPresented: Bool
    
    @StateObject private var viewModel = SettingsViewModel()
    
    // MARK: - Navigation state
    @State private var showBackupView: Bool = false
    @State private var showChangePasscodeView: Bool = false

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                settingsHeaderSection
                
//                generalSection // todo - не нужна секция с паролем на все апп ? !
                
                dataManagementSection // todo вернуть
                
                secretSpaceSection
                
                aboutSection
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.bottom, 100 * scalingFactor)
        }
    }
    
    // MARK: - Settings Header Section
    private var settingsHeaderSection: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                
            Spacer()
                
            ProBadgeView(isPaywallPresented: $isPaywallPresented)
        }
        .padding(.top, 20 * scalingFactor)
    }

    
    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10 * scalingFactor) {
            Text("General")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                SettingsRow(title: "Enable passcode in app", isToggle: true, isOn: $viewModel.isPasscodeEnabledInApp, isFirst: true)
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * scalingFactor)
                
                SettingsRow(title: "Change passcode", icon: "chevron.right", isOn: .constant(false), isNavigation: true, action: {
                    showChangePasscodeView = true
                })
                .disabled(!viewModel.isPasscodeEnabledInApp)
                .opacity(viewModel.isPasscodeEnabledInApp ? 1.0 : 0.5)
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * scalingFactor)
                
                SettingsRow(title: "Face ID in app", isToggle: true, isOn: $viewModel.isFaceIDInAppEnabled, isLast: true)
                .disabled(!viewModel.isPasscodeEnabledInApp)
                .opacity(viewModel.isPasscodeEnabledInApp ? 1.0 : 0.5)
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scalingFactor))
        }
    }
    
    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 10 * scalingFactor) {
            Text("Data Management")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                BackupContactsSettingsRow(
                    scalingFactor: scalingFactor,
                    action: {
                        showBackupView = true
                    }
                )
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scalingFactor))
        }
    }
    
    // MARK: - Secret Space Section
    private var secretSpaceSection: some View {
        VStack(alignment: .leading, spacing: 10 * scalingFactor) {
            Text("Secret space")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                SettingsRow(title: "Change passcode", icon: "chevron.right", isOn: .constant(false), isNavigation: true, isFirst: true, isLast: true, action: {
                    showChangePasscodeView = true
                })
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scalingFactor))
        }
        .fullScreenCover(isPresented: $showChangePasscodeView) {
            PasswordCodeView(
                onTabBarVisibilityChange: { _ in },
                onCodeEntered: { code in
                    print("New passcode saved: \(code)")
                },
                onBackButtonTapped: {
                    showChangePasscodeView = false
                },
                shouldAutoDismiss: true,
                isChangingPasscode: true
            )
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10 * scalingFactor) {
            Text("About")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                
            VStack(spacing: 0) {
                SettingsRow(title: "License agreement", icon: "chevron.right", isOn: .constant(false), isNavigation: true, isFirst: true, action: {
                    viewModel.licenseAgreementTapped()
                })
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * scalingFactor)
                
                SettingsRow(title: "Privacy policy", icon: "chevron.right", isOn: .constant(false), isNavigation: true, action: {
                    viewModel.privacyPolicyTapped()
                })
                
                Divider().background(CMColor.backgroundSecondary).padding(.horizontal, 16 * scalingFactor)
                
                SettingsRow(title: "Send feedback", icon: "chevron.right", isOn: .constant(false), isNavigation: true, isLast: true, action: {
                    viewModel.sendFeedbackTapped()
                })
            }
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scalingFactor))
        }
        .fullScreenCover(isPresented: $showBackupView) {
            BackupView()
        }
    }
}

// MARK: - BackupContactsSettingsRow Custom Component
struct BackupContactsSettingsRow: View {
    let scalingFactor: CGFloat
    let action: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 12 * scalingFactor) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 28 * scalingFactor, height: 28 * scalingFactor)
                        
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
                Text("Backup contacts")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(CMColor.primaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(CMColor.tertiaryText)
                .font(.system(size: 14 * scalingFactor, weight: .medium))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(CMColor.surface)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

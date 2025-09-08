//
//  CustomTabBar.swift
//  cleanme2
//
//  Created by AI Assistant on 10.08.25.
//

import SwiftUI

/// Custom floating tab bar with purple theme and adaptive colors
/// 
/// Features:
/// - Purple gradient for selected state with glow effects
/// - Adaptive colors that work in both light and dark themes
/// - Smooth animations and spring effects
/// - Enhanced visual hierarchy with proper shadows
/// - Accessible contrast ratios maintained across themes

struct CustomTabBar: View {
    @Binding var selectedTab: MediaCleanerViewModel.TabType
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        HStack(spacing: 24 * scalingFactor) {
            ForEach(MediaCleanerViewModel.TabType.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    onTap: {
                        selectedTab = tab
                    }
                )
            }
        }
        .padding(.horizontal, 24 * scalingFactor)
        .padding(.vertical, 8 * scalingFactor)
        .background(CMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28 * scalingFactor))
        .shadow(color: CMColor.primary.opacity(0.12), radius: 20, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 28 * scalingFactor)
                .stroke(CMColor.border.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 358 * scalingFactor, height: 72 * scalingFactor)
        .padding(.horizontal, 16 * scalingFactor)
    }
}

struct TabBarItem: View {
    let tab: MediaCleanerViewModel.TabType
    let isSelected: Bool
    let onTap: () -> Void
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    // Selected state with enhanced purple gradient and glow effect
                    ZStack {
                        // Enhanced glow effect
                        Ellipse()
                            .fill(CMColor.primary.opacity(0.25))
                            .frame(width: 42 * scalingFactor, height: 42 * scalingFactor)
                            .blur(radius: 12 * scalingFactor)
                        
                        // Outer glow ring
                        RoundedRectangle(cornerRadius: 24 * scalingFactor)
                            .fill(CMColor.primary.opacity(0.15))
                            .frame(width: 52 * scalingFactor, height: 52 * scalingFactor)
                        
                        // Main gradient background with purple theme
                        RoundedRectangle(cornerRadius: 20 * scalingFactor)
                            .fill(CMColor.primaryGradient)
                            .frame(width: 48 * scalingFactor, height: 48 * scalingFactor)
                            .shadow(color: CMColor.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .frame(width: 52 * scalingFactor, height: 56 * scalingFactor)
                } else {
                    // Unselected state with subtle background
                    RoundedRectangle(cornerRadius: 20 * scalingFactor)
                        .fill(CMColor.backgroundSecondary.opacity(0.3))
                        .frame(width: 48 * scalingFactor, height: 48 * scalingFactor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20 * scalingFactor)
                                .stroke(CMColor.border.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Icon with improved styling
                Image(systemName: systemImageName(for: tab))
                    .font(.system(size: 20 * scalingFactor, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? CMColor.white : CMColor.iconPrimary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func systemImageName(for tab: MediaCleanerViewModel.TabType) -> String {
        switch tab {
        case .clean:
            return isSelected ? "paintbrush.fill" : "paintbrush"
        case .dashboard:
            return isSelected ? "square.grid.2x2.fill" : "square.grid.2x2"
        case .star:
            return isSelected ? "sparkles" : "sparkles"
        case .safeFolder:
            return isSelected ? "folder.fill" : "folder"
        case .settings:
            return isSelected ? "gearshape.fill" : "gearshape"
        }
    }
}

// MARK: - Home Indicator
struct HomeIndicator: View {
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 100 * scalingFactor)
            .fill(CMColor.primaryText.opacity(0.3))
            .frame(width: 146 * scalingFactor, height: 5 * scalingFactor)
            .padding(.bottom, 21 * scalingFactor)
    }
}

#Preview("Light Theme") {
    VStack {
        Spacer()
        
        CustomTabBar(selectedTab: .constant(.clean))
            .padding(.bottom, 20)
        
        Text("Purple Tab Bar - Light Theme")
            .font(.caption)
            .foregroundColor(CMColor.secondaryText)
            .padding(.bottom, 20)
    }
    .background(CMColor.background)
}

#Preview("Dark Theme") {
    VStack {
        Spacer()
        
        CustomTabBar(selectedTab: .constant(.safeFolder))
            .padding(.bottom, 20)
        
        Text("Purple Tab Bar - Dark Theme")
            .font(.caption)
            .foregroundColor(CMColor.secondaryText)
            .padding(.bottom, 20)
    }
    .background(CMColor.background)
    .preferredColorScheme(.dark)
}

//
//  CMColor.swift
//  cleanme2
//
//  Created by AI Assistant on 10.08.25.
//

import SwiftUI

/// CleanMe Design System Color Palette
/// 
/// This design system follows Apple Design Guidelines with:
/// - Adaptive colors that automatically switch between light and dark themes
/// - High contrast ratios for accessibility (minimum 4.5:1)
/// - Semantic color naming for better maintainability
/// - Elegant purple primary palette with complementary teal and orange accents
/// 
/// ## Color Philosophy:
/// - **Primary**: Purple palette (creativity, elegance, premium feel)
/// - **Secondary**: Teal palette (modern, fresh, complementary)
/// - **Accent**: Orange palette (energy, action, highlights)
/// 
/// ## Usage:
/// All colors should be referenced through CMColor.colorName
/// Colors automatically adapt to light/dark mode through Asset Catalog
/// 
/// ## Accessibility:
/// All text/background combinations meet WCAG AA standards
struct CMColor {
    
    // MARK: - Dynamic Color Creation
    /// Creates a color that adapts to the current color scheme
    private static func dynamicColor(_ name: String) -> Color {
        Color(name)
    }
    
    // MARK: - Primary Colors
    /// Main brand color - adaptive blue palette
    static var primary: Color { dynamicColor("Primary") }
    /// Lighter variant of primary color
    static var primaryLight: Color { dynamicColor("PrimaryLight") }
    /// Darker variant of primary color
    static var primaryDark: Color { dynamicColor("PrimaryDark") }
    /// Secondary color - complementary purple palette
    static var secondary: Color { dynamicColor("Secondary") }
    /// Accent color - vibrant orange for highlights
    static var accent: Color { dynamicColor("Accent") }
    
    // MARK: - Background Colors
    /// Primary background color - pure white/dark
    static var background: Color { dynamicColor("Background") }
    /// Secondary background color - subtle tint
    static var backgroundSecondary: Color { dynamicColor("BackgroundSecondary") }
    /// Surface color for cards and elevated content
    static var surface: Color { dynamicColor("Surface") }
    /// Legacy white color - prefer surface instead
    @available(*, deprecated, message: "Use surface instead for better dark mode support")
    static var cardBackground: Color { surface }
    
    // MARK: - Text Colors
    /// Primary text color - high contrast
    static var primaryText: Color { dynamicColor("TextPrimary") }
    /// Secondary text color - medium contrast
    static var secondaryText: Color { dynamicColor("TextSecondary") }
    /// Tertiary text color - low contrast for subtle elements
    static var tertiaryText: Color { dynamicColor("TextTertiary") }
    
    // MARK: - System Colors
    /// Pure white - use sparingly, prefer surface
    static let white = Color.white
    /// Pure black - use sparingly, prefer primaryText
    static let black = Color.black
    /// Transparent color
    static let clear = Color.clear
    
    // MARK: - Status Colors
    /// Success state color - green palette
    static var success: Color { dynamicColor("Success") }
    /// Warning state color - orange palette
    static var warning: Color { dynamicColor("Warning") }
    /// Error state color - red palette
    static var error: Color { dynamicColor("Error") }
    /// activeButton
    static var activeButton: Color { dynamicColor("activeButton") }

    // MARK: - Icon Colors
    /// Primary icon color - matches primary text
    static var iconPrimary: Color { dynamicColor("IconPrimary") }
    /// Secondary icon color - matches secondary text
    static var iconSecondary: Color { dynamicColor("IconSecondary") }
    
    // MARK: - Border Colors
    /// Standard border color
    static var border: Color { dynamicColor("Border") }
    /// Legacy light border - use border instead
    @available(*, deprecated, message: "Use border instead for better dark mode support")
    static var borderLight: Color { border }
    
    // MARK: - Gradients
    /// Primary gradient using brand colors
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryLight, primary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Secondary gradient for variety
    static var secondaryGradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Subtle background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, backgroundSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme-Aware Color Helper
extension View {
    /// Applies a color that automatically adapts to the current color scheme
    func adaptiveColor(_ color: Color) -> some View {
        self.foregroundColor(color)
    }
    
    /// Applies a background color that automatically adapts to the current color scheme
    func adaptiveBackground(_ color: Color) -> some View {
        self.background(color)
    }
}

// MARK: - Preview
#Preview("Color Palette Demo") {
    ColorPaletteDemo()
}

private struct ColorPaletteDemo: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("CleanMe Color Palette")
                    .font(.title.bold())
                    .foregroundColor(CMColor.primaryText)
                
                // Primary Colors
                colorSection("Primary Colors", colors: [
                    ("Primary", CMColor.primary),
                    ("Primary Light", CMColor.primaryLight),
                    ("Primary Dark", CMColor.primaryDark),
                    ("Secondary", CMColor.secondary),
                    ("Accent", CMColor.accent)
                ])
                
                // Background Colors
                colorSection("Background Colors", colors: [
                    ("Background", CMColor.background),
                    ("Background Secondary", CMColor.backgroundSecondary),
                    ("Surface", CMColor.surface)
                ])
                
                // Text Colors
                colorSection("Text Colors", colors: [
                    ("Primary Text", CMColor.primaryText),
                    ("Secondary Text", CMColor.secondaryText),
                    ("Tertiary Text", CMColor.tertiaryText)
                ])
                
                // Status Colors
                colorSection("Status Colors", colors: [
                    ("Success", CMColor.success),
                    ("Warning", CMColor.warning),
                    ("Error", CMColor.error)
                ])
            }
            .padding()
        }
        .background(CMColor.background)
    }
    
    private func colorSection(_ title: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(CMColor.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .frame(height: 40)
                        
                        Text(name)
                            .font(.caption)
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(CMColor.surface)
        .cornerRadius(12)
    }
}

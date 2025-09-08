import SwiftUI
import UIKit

struct SwipeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            navigationBarView()
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Swipe Mode Image
                    imageView()
                    
                    // Text Content
                    textContent()
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Start Button
            startButton()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }
    
    // MARK: - Navigation Bar
    
    @ViewBuilder
    private func navigationBarView() -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Back")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundColor(.purple)
            }
            
            Spacer()
            
            Text("Swipe Mode")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Invisible placeholder for centering
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text("Back")
                    .font(.system(size: 17, weight: .regular))
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Image View
    
    @ViewBuilder
    private func imageView() -> some View {
        ZStack {
            // Background circle for depth
            Circle()
                .fill(Color(.systemGray6).opacity(0.3))
                .frame(width: 320, height: 320)
                .blur(radius: 20)
            
            // Main image
            Image("smartScan")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 280, height: 280)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
    
    // MARK: - Text Content
    
    @ViewBuilder
    private func textContent() -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Swipe the photo to decide their fate:")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("right - keep, left - delete.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("Organize your gallery in seconds.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Start Button
    
    @ViewBuilder
    private func startButton() -> some View {
        VStack(spacing: 0) {
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                onStart()
                dismiss()
            } label: {
                Text("Start")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34) // Safe area padding
        }
        .background(
            // Background with blur effect
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Preview

struct SwipeOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        SwipeOnboardingView {
            print("Start tapped")
        }
    }
}

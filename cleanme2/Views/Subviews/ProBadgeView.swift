//
//  ProBadgeView.swift
//  cleanme2
//

import SwiftUI

struct ProBadgeView: View {
    @StateObject private var viewModel = MediaCleanerViewModel()
    @Binding var isPaywallPresented: Bool

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: {
            isPaywallPresented = true
        }) {
            // todo PRO
//            HStack(spacing: 4 * scalingFactor) {
//                Image(systemName: "star.fill")
//                    .font(.system(size: 16))
//                    .foregroundColor(CMColor.primaryLight)
//
//                Text("Pro")
//                    .font(.system(size: 17, weight: .semibold))
//                    .foregroundColor(CMColor.primaryLight)
//            }
//            .padding(.horizontal, 10 * scalingFactor)
//            .padding(.vertical, 4 * scalingFactor)
//            .background(CMColor.backgroundSecondary)
//            .clipShape(RoundedRectangle(cornerRadius: 12 * scalingFactor))
//            .opacity(0.8)
        }
    }
}


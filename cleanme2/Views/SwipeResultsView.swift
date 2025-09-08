import SwiftUI
import UIKit

struct SwipeResultsData: Identifiable {
    let id = UUID()
    let savedCount: Int
    let removeCount: Int
    let savedPhotos: [String] // asset localIdentifiers
    let removePhotos: [String] // asset localIdentifiers
}

struct SwipeResultsView: View {
    @ObservedObject var viewModel: SmartCleanViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Computed property для получения актуальных данных
    private var resultsData: SwipeResultsData {
        let data = viewModel.getSwipeResultsData()
        print("UPDATE:COUNT:TEST - SwipeResultsView computed resultsData: savedCount=\(data.savedCount), removeCount=\(data.removeCount)")
        return data
    }
    
    // State для показа SwipePhotoDetailView
    @State private var showRemovePhotosView = false
    @State private var showSavedPhotosView = false
    
    // Callback для обработки финального удаления
    var onFinish: ([String]) -> Void
    
    // Callback для обновления данных после каждого свайпа  
    var onSwipeDecisionChanged: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            navigationBarView()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Saved section
                    savedSection()
                    
                    // Remove section  
                    removeSection()
                    
                    Spacer()
                        .frame(height: 100) // Space for bottom button
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            Spacer()
            
            // Bottom button
            bottomButtonView()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showRemovePhotosView) {
            let removeSections = viewModel.getSectionsForAssetIdentifiers(resultsData.removePhotos)
            SwipePhotoDetailView(
                sections: removeSections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: removeSections,
                    type: .similar // Можно использовать любой тип, так как отображаем смешанные результаты
                ),
                mode: .resultsView,
                onFinish: { updatedDecisions in
                    // Обработка обновленных решений после просмотра
                    print("SWIPE:RESULTS - Updated decisions from remove photos view: \(updatedDecisions.count)")
                    // Здесь можно обновить данные, если нужно
                },
                onSwipeDecisionChanged: onSwipeDecisionChanged
            )
        }
        .fullScreenCover(isPresented: $showSavedPhotosView) {
            let savedSections = viewModel.getSectionsForAssetIdentifiers(resultsData.savedPhotos)
            SwipePhotoDetailView(
                sections: savedSections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: savedSections,
                    type: .similar // Можно использовать любой тип, так как отображаем смешанные результаты
                ),
                mode: .resultsView,
                onFinish: { updatedDecisions in
                    // Обработка обновленных решений после просмотра
                    print("SWIPE:RESULTS - Updated decisions from saved photos view: \(updatedDecisions.count)")
                    // Здесь можно обновить данные, если нужно
                },
                onSwipeDecisionChanged: onSwipeDecisionChanged
            )
        }
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
            
            Text("Results")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                // Finish without deletion - just dismiss
                dismiss()
            } label: {
                Text("Finish")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Saved Section
    
    @ViewBuilder
    private func savedSection() -> some View {
        Button {
            if resultsData.savedCount > 0 {
                showSavedPhotosView = true
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("These photos remain on the device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(resultsData.savedCount)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(resultsData.savedCount == 0)
    }
    
    // MARK: - Remove Section
    
    @ViewBuilder
    private func removeSection() -> some View {
        Button {
            if resultsData.removeCount > 0 {
                showRemovePhotosView = true
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remove")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("These photos will be deleted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(resultsData.removeCount)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(resultsData.removeCount == 0)
    }
    
    // MARK: - Bottom Button
    
    @ViewBuilder
    private func bottomButtonView() -> some View {
        VStack(spacing: 16) {
            if resultsData.removeCount > 0 {
                Button {
                    // Perform deletion
                    onFinish(resultsData.removePhotos)
                    
                    // Add haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    dismiss()
                } label: {
                    Text("Delete \(resultsData.removeCount) photos")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            } else {
                Button {
                    dismiss()
                } label: {
                    Text("No photos to delete")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
                .disabled(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34) // Safe area bottom padding
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

struct SwipeResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SwipeResultsView(
            viewModel: SmartCleanViewModel(),
            onFinish: { photos in
                print("Deleting \(photos.count) photos")
            }
        )
    }
}

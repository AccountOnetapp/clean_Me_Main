//
//  SectionImagesItemPreview.swift
//  cleanme2
//
//  Created by AI Assistant on 25.01.25.
//

import SwiftUI
import Photos

struct SectionImagesItemPreview: View {
    let section: MediaCleanerServiceSection
    @State private var selectedIndex: Int
    @ObservedObject var viewModel: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(section: MediaCleanerServiceSection, initialIndex: Int, viewModel: SimilaritySectionsViewModel) {
        self.section = section
        self._selectedIndex = State(initialValue: initialIndex)
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
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
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("\(section.models.count) photos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText)
                
                Spacer()
                
                Button {
                    // Done action - можно добавить логику сохранения
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CMColor.backgroundSecondary)
            
            // Main Content
            VStack(spacing: 0) {
                // Large Preview Image - занимает всё доступное пространство
                if selectedIndex < section.models.count {
                    let selectedModel = section.models[selectedIndex]
                    
                    // Main Image with proper aspect ratio and corner radius
                    ZStack {
                        selectedModel.imageView(
                            size: CGSize(width: 400, height: 400)
                        )
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 24)) // Правильное скругление
                        .clipped()

                        // Checkbox overlay - в правом верхнем углу превью
                        VStack {
                            HStack {
                                Spacer()
                                
                                CheckboxView(isSelected: viewModel.isSelected(selectedModel))
                                    .scaleEffect(1.2)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.toggleSelection(for: selectedModel)
                                            if !viewModel.isSelectionMode {
                                                viewModel.isSelectionMode = true
                                            }
                                        }
                                    }
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
                
                // Bottom Thumbnail Slider - фиксированная высота
                VStack(spacing: 0) {
                    // Divider line
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            HStack(spacing: 8) {
                                ForEach(section.models.indices, id: \.self) { index in
                                    let model = section.models[index]
                                    
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedIndex = index
                                        }
                                    } label: {
                                        ZStack {
                                            // Thumbnail Image
                                            model.imageView(size: CGSize(width: 70, height: 70))
                                                .frame(width: 70, height: 70)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            
                                            // Selection indicator
                                            if viewModel.isSelected(model) {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        CheckboxView(isSelected: true)
                                                            .scaleEffect(0.8)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(6)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedIndex == index ? Color.blue : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .scaleEffect(selectedIndex == index ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .onAppear {
                                proxy.scrollTo(selectedIndex, anchor: .center)
                            }
                            .onChange(of: selectedIndex) { newIndex in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                    .frame(height: 102) // Фиксированная высота для слайдера
                }
                .background(CMColor.backgroundSecondary)
            }
        }
        .background(CMColor.backgroundSecondary)
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
#if DEBUG
struct SectionImagesItemPreview_Previews: PreviewProvider {
    static var previews: some View {
        // Mock data for preview
        let mockSection = MediaCleanerServiceSection(
            kind: .count,
            models: [] // В реальном приложении здесь будут модели
        )
        let mockViewModel = SimilaritySectionsViewModel(
            sections: [mockSection],
            type: .similar
        )
        
        SectionImagesItemPreview(
            section: mockSection,
            initialIndex: 0,
            viewModel: mockViewModel
        )
    }
}
#endif

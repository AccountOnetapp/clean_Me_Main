import SwiftUI
import Photos

struct SimilaritySectionsView: View {
    @StateObject private var viewModel: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: MediaCleanerServiceSection?
    @State private var selectedImageIndex: Int = 0

    init(viewModel: SimilaritySectionsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                        Text("Media")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(viewModel.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText)
                
                Spacer()
                
                Button {
                    if viewModel.hasSelectedItems {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                } label: {
                    Text(viewModel.hasSelectedItems ? "Deselect All" : "Select All")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CMColor.backgroundSecondary)

            ZStack {
        ScrollView(.vertical) {
            VStack(spacing: 32) {
                        ForEach(viewModel.sections.indices, id: \.self) { index in
                            getSectionView(for: viewModel.sections[index])
                        }
                    }
                    .padding(12)
                    .padding(.bottom, viewModel.hasSelectedItems ? 100 : 0) // Отступ для кнопки удаления
                }
                .background(CMColor.backgroundSecondary)

                // Анимированная кнопка удаления
                VStack {
                    Spacer()
                    
                    if viewModel.hasSelectedItems {
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                viewModel.deleteSelected()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Delete \(viewModel.selectedCount) item\(viewModel.selectedCount == 1 ? "" : "s")")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 34) // Safe area bottom
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.hasSelectedItems)
            }
        }
        .background(CMColor.backgroundSecondary)
        .fullScreenCover(item: $selectedSection) { section in
            if viewModel.type == .videos {
                SectionVideosItemPreview(
                    section: section,
                    initialIndex: selectedImageIndex,
                    viewModel: viewModel
                )
            } else {
                SectionImagesItemPreview(
                    section: section,
                    initialIndex: selectedImageIndex,
                    viewModel: viewModel
                )
            }
        }
    }

    private func getSectionView(for section: MediaCleanerServiceSection) -> some View {
        LazyVStack(spacing: 12) {
            HStack(alignment: .center) {
                switch section.kind {
                case .count:
                    Text("\(section.models.count) items")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)

                case .date(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)

                case .united(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if viewModel.isAllSelectedInSection(section) {
                            viewModel.deselectAllInSection(section)
                        } else {
                            viewModel.selectAllInSection(section)
                        }
                    }
                } label: {
                    Text(viewModel.isAllSelectedInSection(section) ? "Deselect all" : "Select all")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(viewModel.isAllSelectedInSection(section) ? Color.red : CMColor.primaryText)
                }
            }

            LazyVStack(alignment: .leading, spacing: 8) {
                if viewModel.type == .duplicates || viewModel.type == .similar {
                    getMainItemView(for: section)
                }

                let remainingModels = viewModel.type == .duplicates || viewModel.type == .similar ? Array(section.models.suffix(from: 1)) : section.models
                FlexibleWrappingHStack(remainingModels.indices) { index in
                    let model = remainingModels[index]
                    let actualIndex = viewModel.type == .duplicates || viewModel.type == .similar ? index + 1 : 0 // +1 because we skip first element
                    getItemView(for: model, section: section, index: actualIndex)
                }
            }
        }
    }

    private func getMainItemView(for section: MediaCleanerServiceSection) -> some View {
        VStack {
            if let firstModel = section.models.first {
                Button {
                    // Открываем детальный экран
                    selectedImageIndex = 0
                    selectedSection = section
                } label: {
                    ZStack {
                        firstModel.imageView(size: CGSize(width: 176, height: 176))
                        
                        // Добавляем индикатор видео если это видео
                        if viewModel.type == .videos {
                            // Play icon overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                            
                            // Duration overlay в правом нижнем углу
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(firstModel.formattedDuration)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Rectangle()
                    .frame(width: 176, height: 176)
                    .foregroundStyle(Color.gray.opacity(0.3))
            }
        }
        .frame(width: 176, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .clipped()
        .overlay {
            VStack {
                // Чекбокс в верхнем правом углу
                HStack {
                    Spacer()
                    
                    if let firstModel = section.models.first {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleSelection(for: firstModel)
                                if !viewModel.isSelectionMode {
                                    viewModel.isSelectionMode = true
                                }
                            }
                        } label: {
                            CheckboxView(isSelected: viewModel.isSelected(firstModel))
                        }
                    }
                }
                
                Spacer()

                HStack {
                    Text("Best")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(CMColor.border)
                        .clipShape(RoundedRectangle(cornerRadius: 15))

                    Spacer()
                }
            }
            .padding(12)
        }
        .scaleEffect(section.models.first.map { viewModel.isSelected($0) } ?? false ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: section.models.first.map { viewModel.isSelected($0) } ?? false)
    }

    private func getItemView(for model: MediaCleanerServiceModel, section: MediaCleanerServiceSection, index: Int) -> some View {
        // Учитываем: padding контейнера (12*2) + отступы между элементами (8*3) + запас
        let itemSize = (UIScreen.main.bounds.width - 24 - 24 - 16) / 4

        return Button {
            // Открываем детальный экран с выбранным индексом
            selectedImageIndex = index
            selectedSection = section
        } label: {
            VStack {
                ZStack {
                    model.imageView(
                        size: CGSize(width: itemSize, height: itemSize)
                    )
                    
                    // Добавляем индикатор видео если это видео
                    if viewModel.type == .videos {
                        // Play icon overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        // Duration overlay в правом нижнем углу
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(model.formattedDuration)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .padding(3)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: itemSize, height: itemSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
        .overlay(
            // Чекбокс в верхнем правом углу
            VStack {
                HStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleSelection(for: model)
                            if !viewModel.isSelectionMode {
                                viewModel.isSelectionMode = true
                            }
                        }
                    } label: {
                        CheckboxView(isSelected: viewModel.isSelected(model))
                            .scaleEffect(0.8) // Меньший размер для маленьких изображений
                    }
                }
                Spacer()
            }
            .padding(4)
        )
        .scaleEffect(viewModel.isSelected(model) ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSelected(model))
    }
}

// MARK: - CheckboxView Component
struct CheckboxView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isSelected ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

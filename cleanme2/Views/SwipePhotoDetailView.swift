import SwiftUI
import Photos
import UIKit

enum SwipePhotoDetailMode {
    case swipeMode  // Обычный режим свайпов (показывать confirmation dialog)
    case resultsView // Просмотр результатов (не показывать dialog)
}

enum PhotoSwipeDecision: String, CaseIterable {
    case none
    case keep
    case delete
    
    var color: Color {
        switch self {
        case .none:
            return .clear
        case .keep:
            return .green
        case .delete:
            return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return ""
        case .keep:
            return "checkmark"
        case .delete:
            return "xmark"
        }
    }
}

struct SwipePhotoDetailView: View {
    let sections: [MediaCleanerServiceSection]
    @State private var selectedIndex: Int
    @ObservedObject var viewModel: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Mode и callbacks
    let mode: SwipePhotoDetailMode
    var onShowResults: (() -> Void)? // Callback для открытия SwipeResults
    
    // Cache service для сохранения swipe решений
    private let cacheService: MediaCleanerCacheService = MediaCleanerCacheServiceImpl.shared
    
    // Swipe state
    @State private var dragOffset: CGFloat = 0
    @State private var currentDecision: PhotoSwipeDecision = .none
    @State private var photoDecisions: [String: PhotoSwipeDecision] = [:]
    
    // UI State
    @State private var showSwipeIndicator = false
    @State private var isAnimatingCard = false
    @State private var animatingCardOffset: CGFloat = 0
    @State private var animatingCardId: String? = nil
    @State private var showExitConfirmation = false
    
    private let swipeThreshold: CGFloat = 100
    
    // Combined models from all sections
    private var allModels: [MediaCleanerServiceModel] {
        return sections.flatMap { $0.models }
    }
    
    // Количество элементов для удаления
    private var deleteCount: Int {
        return cacheService.getTotalSwipeDecisionsForDeletion()
    }
    

    
    // New closure to handle completion
    var onFinish: ([String: PhotoSwipeDecision]) -> Void
    // Callback для обновления данных после каждого свайпа
    var onSwipeDecisionChanged: (() -> Void)?
    
    init(sections: [MediaCleanerServiceSection], initialIndex: Int, viewModel: SimilaritySectionsViewModel, mode: SwipePhotoDetailMode = .swipeMode, onFinish: @escaping ([String: PhotoSwipeDecision]) -> Void, onShowResults: (() -> Void)? = nil, onSwipeDecisionChanged: (() -> Void)? = nil) {
        self.sections = sections
        self._selectedIndex = State(initialValue: initialIndex)
        self.viewModel = viewModel
        self.mode = mode
        self.onFinish = onFinish
        self.onShowResults = onShowResults
        self.onSwipeDecisionChanged = onSwipeDecisionChanged
        print("SWIPE:TEST - SwipePhotoDetailView init: initialIndex=\(initialIndex), totalModels=\(sections.flatMap { $0.models }.count), mode=\(mode)")
    }
    
    // MARK: - Cache Helper Methods
    
    /// Конвертирует PhotoSwipeDecision в Bool для MediaCleanerCacheService
    /// - Parameter decision: PhotoSwipeDecision (.keep, .delete, .none)
    /// - Returns: Bool? где true = ignored (keep), false = selected for deletion, nil = no decision
    private func decisionToCacheValue(_ decision: PhotoSwipeDecision) -> Bool? {
        switch decision {
        case .keep:
            return true    // ignored = true (keep the photo)
        case .delete:
            return false   // ignored = false (selected for smart cleaning/deletion)
        case .none:
            return nil     // no decision
        }
    }
    
    /// Конвертирует Bool из MediaCleanerCacheService в PhotoSwipeDecision
    /// - Parameter cacheValue: Bool? где true = ignored, false = selected for deletion, nil = no decision
    /// - Returns: PhotoSwipeDecision
    private func cacheValueToDecision(_ cacheValue: Bool?) -> PhotoSwipeDecision {
        guard let cacheValue = cacheValue else { return .none }
        return cacheValue ? .keep : .delete
    }
    
    /// Загружает сохраненные swipe решения для всех фото
    private func loadSavedSwipeDecisions() {
        print("SWIPE:CACHE - Loading saved swipe decisions for \(allModels.count) photos")
        
        for model in allModels {
            let assetId = model.asset.localIdentifier
            let savedDecision = cacheService.getSwipeDecision(id: assetId)
            let photoDecision = cacheValueToDecision(savedDecision)
            
            if photoDecision != .none {
                photoDecisions[assetId] = photoDecision
                print("SWIPE:CACHE - Loaded decision for \(assetId): \(photoDecision)")
            }
        }
        
        print("SWIPE:CACHE - Loaded \(photoDecisions.count) saved swipe decisions")
    }
    
    /// Сохраняет swipe решение в кеш
    /// - Parameters:
    ///   - assetId: Идентификатор фото
    ///   - decision: Принятое решение
    private func saveSwipeDecision(for assetId: String, decision: PhotoSwipeDecision) {
        print("SWIPE:CACHE - Saving swipe decision for \(assetId): \(decision)")
        print("UPDATE:COUNT:TEST - saveSwipeDecision called for \(assetId): \(decision)")
        
        if let cacheValue = decisionToCacheValue(decision) {
            cacheService.setSwipeDecision(id: assetId, ignored: cacheValue)
            print("SWIPE:CACHE - Saved to cache: \(assetId) = \(cacheValue) (ignored)")
            print("UPDATE:COUNT:TEST - Saved to cache: \(assetId) = \(cacheValue)")
        } else {
            // Если decision == .none, удаляем из кеша
            cacheService.deleteSwipeDecision(id: assetId)
            print("SWIPE:CACHE - Deleted decision from cache for \(assetId)")
            print("UPDATE:COUNT:TEST - Deleted decision from cache for \(assetId)")
        }
        
        // Уведомляем родительские экраны об изменениях
        print("UPDATE:COUNT:TEST - About to call onSwipeDecisionChanged callback")
        if let callback = onSwipeDecisionChanged {
            print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback exists, calling it")
            callback()
            print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback called successfully")
        } else {
            print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback is nil!")
        }
    }
    
    /// Очищает swipe решение для фото (длинное нажатие)
    /// - Parameter assetId: Идентификатор фото
    private func clearSwipeDecision(for assetId: String) {
        print("SWIPE:CACHE - Clearing swipe decision for \(assetId)")
        print("UPDATE:COUNT:TEST - clearSwipeDecision called for \(assetId)")
        
        // Анимированно обновляем UI
        let _ = withAnimation(.easeInOut(duration: 0.3)) {
            // Удаляем из локального словаря
            photoDecisions.removeValue(forKey: assetId)
        }
        
        // Удаляем из кеша
        cacheService.deleteSwipeDecision(id: assetId)
        
        print("SWIPE:CACHE - Cleared decision for \(assetId)")
        print("UPDATE:COUNT:TEST - Deleted decision from cache for \(assetId)")
        
        // Небольшая вибрация для обратной связи
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Уведомляем родительские экраны об изменениях
        print("UPDATE:COUNT:TEST - About to call onSwipeDecisionChanged callback from clearSwipeDecision")
        if let callback = onSwipeDecisionChanged {
            print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback exists in clearSwipeDecision, calling it")
            callback()
            print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback called successfully from clearSwipeDecision")
        } else {
            print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback is nil in clearSwipeDecision!")
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleBackAction() {
        switch mode {
        case .swipeMode:
            // В режиме свайпов показываем confirmation dialog только если есть элементы для удаления
            if deleteCount > 0 {
                showExitConfirmation = true
            } else {
                // Если нет элементов для удаления, сразу закрываем
                dismiss()
            }
        case .resultsView:
            // В режиме просмотра результатов сразу закрываем
            dismiss()
        }
    }
    
    private func handleFinishAction() {
        switch mode {
        case .swipeMode:
            // В режиме свайпов показываем confirmation dialog только если есть элементы для удаления
            if deleteCount > 0 {
                showExitConfirmation = true
            } else {
                // Если нет элементов для удаления, просто передаем пустые решения и закрываем
                onFinish(photoDecisions)
                dismiss()
            }
        case .resultsView:
            // В режиме просмотра результатов передаем данные и закрываем
            onFinish(photoDecisions)
            dismiss()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Навигационная панель остается вверху
            navigationBarView()
            
            // Spacer растягивается и занимает все доступное пространство
            Spacer()
            
            // Этот VStack будет центрировать контент, когда он есть
            VStack(spacing: 0) {
                swipeImageView()
                thumbnailSliderView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CMColor.backgroundSecondary)
        .navigationBarHidden(true)
        .overlay {
            if showExitConfirmation {
                SwipeResultsPopup(
                    deleteCount: deleteCount,
                    isPresented: $showExitConfirmation,
                    onViewResults: {
                        onShowResults?()
                        dismiss()
                    },
                    onContinueSwiping: {
                        // Закрываем весь экран SwipePhotoDetailView
                        dismiss()
                    }
                )
            }
        }
    }
    

    
    // MARK: - Navigation Bar
    
    @ViewBuilder
    private func navigationBarView() -> some View {
        HStack {
            Button {
                handleBackAction()
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
            
            VStack(spacing: 2) {
            Text("Swipe Mode")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CMColor.primaryText)
                
                Text("Long press thumbnail to clear")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CMColor.primaryText.opacity(0.6))
            }
            
            Spacer()
            
            Button {
                handleFinishAction()
            } label: {
                Text("Finish")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CMColor.backgroundSecondary)
    }
    
    // MARK: - Swipe Image View
    
    @ViewBuilder
    private func swipeImageView() -> some View {
        ZStack {
            // Отображаем карточку для текущего selectedIndex
            let currentIndex = selectedIndex
            
            // Отображаем только 3 карточки (текущую и две следующие)
            // Если selectedIndex выходит за границы, используем последний валидный индекс
            let safeCurrentIndex = min(currentIndex, allModels.count - 1)
            ForEach(allModels.indices.filter { $0 >= safeCurrentIndex && $0 < min(safeCurrentIndex + 3, allModels.count) }, id: \.self) { modelIndex in
                let isTopCard = modelIndex == safeCurrentIndex
                let model = allModels[modelIndex]
                
                // Если карточка была свайпнута, отображаем её, но с индикатором и без drag-жеста
//                let isSwiped = photoDecisions[model.asset.localIdentifier] != nil

                ZStack {
                    model.imageView(size: CGSize(width: 400, height: 400))
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .clipped()
                    
                    if isTopCard && !isAnimatingCard {
                        // Индикаторы свайпа
                        swipeIndicatorsView()
                    }
                
                    // Отображаем индикатор "свайпнуто", если решение уже принято
                    if let decision = photoDecisions[model.asset.localIdentifier], isTopCard && !isAnimatingCard {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(decision.color.opacity(0.8))
                                        .frame(width: 80, height: 80)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    Image(systemName: decision.iconName)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                        .transition(.opacity.animation(.easeIn))
                    }
                }
                .scaleEffect({
                        if isTopCard {
                        return 1.0
                        } else {
                        return 1.0 - CGFloat(modelIndex - safeCurrentIndex) * 0.05
                        }
                    }())
                    .offset(x: {
                        if isTopCard {
                            return dragOffset * 0.8
                        } else {
                            return 0
                        }
                }(), y: CGFloat(modelIndex - safeCurrentIndex) * 8)
                    .rotationEffect(.degrees({
                        if isTopCard {
                            return dragOffset / 20
                        } else {
                            return 0
                        }
                    }()))
                .opacity(isTopCard ? 1.0 : (1.0 - CGFloat(modelIndex - safeCurrentIndex) * 0.25))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedIndex)
                .zIndex(Double(10 - (modelIndex - safeCurrentIndex)))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Ваша логика onChanged без изменений
                    guard !isAnimatingCard else { return }
                    dragOffset = value.translation.width
                    
                    let oldDecision = currentDecision
                    if dragOffset > swipeThreshold {
                        currentDecision = .keep
                    } else if dragOffset < -swipeThreshold {
                        currentDecision = .delete
                    } else {
                        currentDecision = .none
                    }
                    
                    if oldDecision != currentDecision {
                        print("SWIPE:TEST - Decision changed: \(oldDecision) -> \(currentDecision)")
                    }
                    
                    showSwipeIndicator = abs(dragOffset) > 20
                }
                .onEnded { value in
                    guard !isAnimatingCard else { return }
                    
                    let finalDecision: PhotoSwipeDecision
                    if dragOffset > swipeThreshold {
                        finalDecision = .keep
                    } else if dragOffset < -swipeThreshold {
                        finalDecision = .delete
                    } else {
                        finalDecision = .none
                    }
                    
                    if finalDecision != .none {
                        let safeIndex = min(selectedIndex, allModels.count - 1)
                        let currentModel = allModels[safeIndex]
                        let assetId = currentModel.asset.localIdentifier
                        photoDecisions[assetId] = finalDecision
                        
                        // Сохраняем решение в кеш
                        saveSwipeDecision(for: assetId, decision: finalDecision)
                        
                        isAnimatingCard = true
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            dragOffset = finalDecision == .keep ? 1000 : -1000
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedIndex += 1
                            isAnimatingCard = false
                            dragOffset = 0
                            currentDecision = .none
                            showSwipeIndicator = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = 0
                            currentDecision = .none
                            showSwipeIndicator = false
                        }
                    }
                }
        )
    }
    
    // MARK: - Swipe Indicators
    
    @ViewBuilder
    private func swipeIndicatorsView() -> some View {
        if dragOffset < -30 {
            VStack {
                HStack {
                    Spacer() 
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 80, height: 80)
                            .opacity(min(abs(dragOffset) / swipeThreshold, 1.0))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                        Image(systemName: "xmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(currentDecision == .delete ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: currentDecision)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
                }
                .padding(.top, 32)
                .padding(.trailing, 32)
                
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
        
        if dragOffset > 30 {
            VStack {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 80, height: 80)
                            .opacity(min(abs(dragOffset) / swipeThreshold, 1.0))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(currentDecision == .keep ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: currentDecision)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
                    
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.leading, 32)
                
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Thumbnail Slider
    
    @ViewBuilder
    private func thumbnailSliderView() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 8) {
                        ForEach(allModels.indices, id: \.self) { index in
                            let model = allModels[index]
                            let decision = photoDecisions[model.asset.localIdentifier] ?? .none
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedIndex = index
                                }
                            } label: {
                                model.imageView(size: CGSize(width: 70, height: 70))
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                min(selectedIndex, allModels.count - 1) == index ? Color.blue : decision.color,
                                                lineWidth: min(selectedIndex, allModels.count - 1) == index ? 3 : (decision != .none ? 2 : 0)
                                            )
                                    )
                                    .scaleEffect(min(selectedIndex, allModels.count - 1) == index ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                                    .overlay(
                                        Group {
                                            if decision != .none {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        
                                                        ZStack {
                                                            Circle()
                                                                .fill(decision.color)
                                                                .frame(width: 20, height: 20)
                                                            
                                                            Image(systemName: decision.iconName)
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(.white)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(4)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onLongPressGesture {
                                // Длинное нажатие - очищаем решение для этого фото
                                clearSwipeDecision(for: model.asset.localIdentifier)
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .onAppear {
                        let safeIndex = min(selectedIndex, allModels.count - 1)
                        proxy.scrollTo(safeIndex, anchor: .center)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            let safeIndex = min(newIndex, allModels.count - 1)
                            proxy.scrollTo(safeIndex, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: 102)
        }
        .background(CMColor.backgroundSecondary)
        .onAppear {
            print("SWIPE:TEST - SwipePhotoDetailView onAppear: selectedIndex=\(selectedIndex)")
            // Загружаем сохраненные swipe решения
            loadSavedSwipeDecisions()
        }
        .onChange(of: selectedIndex) { newValue in
            print("SWIPE:TEST - selectedIndex changed in onChange: \(selectedIndex) -> \(newValue)")
        }
        .onChange(of: animatingCardOffset) { newValue in
            print("SWIPE:TEST - animatingCardOffset changed: \(newValue)")
        }
        .onChange(of: animatingCardId) { newValue in
            print("SWIPE:TEST - animatingCardId changed: \(String(describing: newValue))")
        }
        .onChange(of: isAnimatingCard) { newValue in
            print("SWIPE:TEST - isAnimatingCard changed: \(newValue)")
        }
    }
}

// MARK: - SwipeResultsPopup

struct SwipeResultsPopup: View {
    let deleteCount: Int
    @Binding var isPresented: Bool
    let onViewResults: () -> Void
    let onContinueSwiping: () -> Void
    
    @State private var showContent = false
    @State private var backgroundOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // Blur effect
            VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // Popup content
            VStack(spacing: 24) {
                // Header with icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("Ready to see your results?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("You've selected \(deleteCount) photo\(deleteCount == 1 ? "" : "s") for deletion. Would you like to review your selections?")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                
                // Buttons
                VStack(spacing: 12) {
                    // Primary button - View Results
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showContent = false
                            backgroundOpacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onViewResults()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("View Results (\(deleteCount) to delete)")
                                .font(.system(size: 17, weight: .semibold))
                        }
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
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showContent)
                    
                    // Secondary button - Close
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismissPopup()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Close")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: showContent)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .scaleEffect(showContent ? 1 : 0.7)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showContent)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundOpacity = 0.4
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    private func dismissPopup() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Сразу закрываем экран без анимации popup, поскольку весь экран будет закрываться
        onContinueSwiping()
    }
}

// MARK: - VisualEffectView

struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect?
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

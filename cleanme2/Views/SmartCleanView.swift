import SwiftUI
import Combine
import UIKit

struct SwipeViewData: Identifiable {
    let id = UUID()
    let sections: [MediaCleanerServiceSection]
    let type: ScanItemType
}

struct SmartCleanView: View {
    @StateObject private var viewModel = SmartCleanViewModel()
    @Binding var isPaywallPresented: Bool
    
    @State private var presentedSwipeView: SwipeViewData?
    @State private var presentedResultsView: SwipeResultsData?
    @State private var showSwipeOnboarding = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    headerView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    swipeModeSection()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    
                    categoriesGrid()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(item: $presentedSwipeView) { swipeData in
            SwipePhotoDetailView(
                sections: swipeData.sections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: swipeData.sections,
                    type: swipeData.type
                ),
                mode: .swipeMode,
                onFinish: { decisions in
                    viewModel.processSwipeDecisions(decisions)
                },
                onShowResults: {
                    // Закрываем текущий swipe view и показываем результаты
                    presentedSwipeView = nil
                    let resultsData = viewModel.getSwipeResultsData()
                    presentedResultsView = resultsData
                },
                onSwipeDecisionChanged: {
                    print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback called in SmartCleanView from SwipePhotoDetailView")
                    // Обновляем счетчики после каждого свайпа
                    viewModel.updateTotalSwipeDecisionsCount()
                }
            )
        }
        .fullScreenCover(item: $presentedResultsView) { _ in
            SwipeResultsView(
                viewModel: viewModel,
                onFinish: { photosToDelete in
                    viewModel.finalizePhotoDeletion(photosToDelete)
                },
                onSwipeDecisionChanged: {
                    print("UPDATE:COUNT:TEST - onSwipeDecisionChanged callback called in SmartCleanView from SwipeResultsView")
                    // Обновляем счетчики также и из SwipeResultsView
                    viewModel.updateTotalSwipeDecisionsCount()
                }
            )
        }
        .fullScreenCover(isPresented: $showSwipeOnboarding) {
            SwipeOnboardingView {
                // Когда пользователь нажимает Start в onboarding
                let allSections = [
                    viewModel.getSections(for: .image(.similar)),
                    viewModel.getSections(for: .image(.blurred)),
                    viewModel.getSections(for: .image(.duplicates)),
                    viewModel.getSections(for: .image(.screenshots))
                ].flatMap { $0 }
                
                if !allSections.isEmpty {
                    presentedSwipeView = SwipeViewData(sections: allSections, type: .similar)
                }
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func headerView() -> some View {
        HStack {
            Text("AI Smart CleanUp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            // todo PRO
//            Button(action: {
//                isPaywallPresented = true
//            }) { 
//                HStack(spacing: 8) {
//                    Text("Pro")
//                        .fontWeight(.semibold)
//                    Image(systemName: "star.fill")
//                        .font(.system(size: 16))
//                }
//                .foregroundColor(.white)
//                .padding(.horizontal, 16)
//                .padding(.vertical, 10)
//                .background(
//                    LinearGradient(
//                        colors: [Color.purple, Color.blue],
//                        startPoint: .leading,
//                        endPoint: .trailing
//                    )
//                )
//                .clipShape(Capsule())
//            }
        }
        .padding(.top, 12)
    }
    
    // MARK: - Swipe Mode Section
    
    @ViewBuilder
    private func swipeModeSection() -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 80)
                    
                    Image("smartScan")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 70, maxHeight: 70)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Swipe Mode")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Swipe the photo to decide their fate: right - keep, left - delete.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            Button(action: {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true // Показываем пейволл
                } else {
                    showSwipeOnboarding = true // Запускаем функционал только при наличии подписки
                }
            }) {
                HStack {
                    Text("Enable swipe mode")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // View Results button - Enhanced Design
            if viewModel.hasSwipeResults {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    let resultsData = viewModel.getSwipeResultsData()
                    presentedResultsView = resultsData
                }) {
                    HStack(spacing: 16) {
                        // Icon Container
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.orange, Color.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        // Text Content
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("View Swipe Results")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                            
                            Text("\(viewModel.swipeResultsSummary)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // Arrow with background
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.9),
                                Color.blue.opacity(0.8),
                                Color.pink.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: Color.purple.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                    .shadow(
                        color: Color.pink.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        // Subtle highlight
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.hasSwipeResults)
                }
                .buttonStyle(SwipeResultsButtonStyle())
            }
        }
        .padding(20)
        .background(CMColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Categories Grid
    
    @ViewBuilder
    private func categoriesGrid() -> some View {
        let cardSize = UIScreen.main.bounds.width / 2 - 24
        
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
            spacing: 16
        ) {
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.similar))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipeViewData(sections: sections, type: .similar)
                    }
                }
            } label: {
                getItem(
                    for: .similar,
                    image: viewModel.similarPreview,
                    count: viewModel.similarCount,
                    sizeStr: formatMegabytes(viewModel.similarMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
            
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.blurred))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipeViewData(sections: sections, type: .blurred)
                    }
                }
            } label: {
                getItem(
                    for: .blurred,
                    image: viewModel.blurredPreview,
                    count: viewModel.blurredCount,
                    sizeStr: formatMegabytes(viewModel.blurredMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
            
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.duplicates))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipeViewData(sections: sections, type: .duplicates)
                    }
                }
            } label: {
                getItem(
                    for: .duplicates,
                    image: viewModel.duplicatesPreview,
                    count: viewModel.duplicatesCount,
                    sizeStr: formatMegabytes(viewModel.duplicatesMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
            
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.screenshots))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipeViewData(sections: sections, type: .screenshots)
                    }
                }
            } label: {
                getItem(
                    for: .screenshots,
                    image: viewModel.screenshotsPreview,
                    count: viewModel.screenshotsCount,
                    sizeStr: formatMegabytes(viewModel.screenshotsMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Get Item (From ScanView)
    
    private func getItem(
        for type: ScanItemType,
        image: UIImage?,
        count: Int,
        sizeStr: String,
        size: CGFloat
    ) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .frame(width: size, height: size)
                    .scaledToFit()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            
            VStack {
                HStack {
                    Text(type.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CMColor.border)
                        .cornerRadius(12)
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    Text(getItemCountText(for: type, count: count, sizeStr: sizeStr))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CMColor.background)
                        .cornerRadius(12)
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(CMColor.backgroundSecondary)
        )
        .clipped()
    }
    
    // MARK: - Helpers
    
    private func getItemCountText(for type: ScanItemType, count: Int, sizeStr: String) -> String {
        if count == 0 {
            return "No items"
        } else {
            return "\(count) items • \(sizeStr)"
        }
    }
    
    private func formatMegabytes(_ megabytes: Double) -> String {
        if megabytes < 1 {
            return String(format: "%.1f KB", megabytes * 1024)
        } else if megabytes < 1024 {
            return String(format: "%.0f MB", megabytes)
        } else {
            return String(format: "%.1f GB", megabytes / 1024)
        }
    }
}

// MARK: - ViewModel

@MainActor
class SmartCleanViewModel: ObservableObject {
    @Published var similarCount = 0
    @Published var blurredCount = 0
    @Published var duplicatesCount = 0
    @Published var screenshotsCount = 0
    
    @Published var similarMegabytes = 0.0
    @Published var blurredMegabytes = 0.0
    @Published var duplicatesMegabytes = 0.0
    @Published var screenshotsMegabytes = 0.0
    
    @Published var similarPreview: UIImage?
    @Published var blurredPreview: UIImage?
    @Published var duplicatesPreview: UIImage?
    @Published var screenshotsPreview: UIImage?
    
    // Swipe results tracking
    @Published var swipeDecisions: [String: PhotoSwipeDecision] = [:]
    @Published var totalSwipeDecisionsForDeletion = 0 {
        willSet {
            print("UPDATE:COUNT:TEST - @Published totalSwipeDecisionsForDeletion will change from \(totalSwipeDecisionsForDeletion) to \(newValue)")
        }
        didSet {
            print("UPDATE:COUNT:TEST - @Published totalSwipeDecisionsForDeletion did change from \(oldValue) to \(totalSwipeDecisionsForDeletion)")
        }
    }
    
    var hasSwipeResults: Bool {
        let result = totalSwipeDecisionsForDeletion > 0
        print("UPDATE:COUNT:TEST - hasSwipeResults computed: totalSwipeDecisionsForDeletion=\(totalSwipeDecisionsForDeletion), result=\(result)")
        return result
    }
    
    var swipeResultsSummary: String {
        let totalSavedInCache = getTotalSavedInCache()
        return "Saved: \(totalSavedInCache), Remove: \(totalSwipeDecisionsForDeletion)"
    }
    
    private let purchaseService = ApphudPurchaseService()

    var hasActiveSubscription: Bool {
        purchaseService.hasActiveSubscription
    }
    
    private let mediaCleanerService: MediaCleanerService = MediaCleanerServiceImpl.shared
    private let cacheService: MediaCleanerCacheService = MediaCleanerCacheServiceImpl.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadExistingSwipeDecisions()
        updateTotalSwipeDecisionsCount()
    }
    
    // MARK: - Public Methods
    
    func getSections(for type: MediaCleanerServiceType) -> [MediaCleanerServiceSection] {
        return mediaCleanerService.getMedia(type)
    }
    
    func processSwipeDecisions(_ decisions: [String: PhotoSwipeDecision]) {
        // Сохраняем решения локально для отображения в UI
        swipeDecisions = decisions
        // Обновляем общий счетчик из кеша
        updateTotalSwipeDecisionsCount()
        print("SWIPE:RESULTS - Processed \(decisions.count) swipe decisions, total for deletion: \(totalSwipeDecisionsForDeletion)")
    }
    
    func getSwipeResultsData() -> SwipeResultsData {
        print("UPDATE:COUNT:TEST - getSwipeResultsData() called")
        
        // Получаем актуальные данные из кеша вместо локальных swipeDecisions
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        var savedPhotos: [String] = []
        var removePhotos: [String] = []
        
        for section in allSections {
            for model in section.models {
                let assetId = model.asset.localIdentifier
                if let cacheDecision = cacheService.getSwipeDecision(id: assetId) {
                    if cacheDecision == true {
                        // ignored = true означает keep
                        savedPhotos.append(assetId)
                    } else {
                        // ignored = false означает delete
                        removePhotos.append(assetId)
                    }
                }
            }
        }
        
        let data = SwipeResultsData(
            savedCount: savedPhotos.count,
            removeCount: removePhotos.count,
            savedPhotos: savedPhotos,
            removePhotos: removePhotos
        )
        
        print("UPDATE:COUNT:TEST - getSwipeResultsData() returning: savedCount=\(data.savedCount), removeCount=\(data.removeCount)")
        return data
    }
    
    func finalizePhotoDeletion(_ photosToDelete: [String]) {
        print("SWIPE:RESULTS - Finalizing deletion of \(photosToDelete.count) photos")
        
        mediaCleanerService.deleteAssets(localIdentifiers: photosToDelete) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedIdentifiers):
                    print("SWIPE:RESULTS - Successfully deleted \(deletedIdentifiers.count) assets.")
                    
                    // Очищаем swipe решения после успешного удаления
                    self.clearSwipeDecisions(for: deletedIdentifiers)
                    
                    // Обновляем общий счетчик swipe decisions для удаления
                    self.updateTotalSwipeDecisionsCount()
                    
                    // Обновляем счётчики и превью
                    self.mediaCleanerService.updateCountsAndPreviews()
                    
                case .failure(let error):
                    print("SWIPE:RESULTS - Failed to delete assets: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadExistingSwipeDecisions() {
        // Загружаем сохранённые swipe решения из кеша при инициализации
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        var loadedDecisions: [String: PhotoSwipeDecision] = [:]
        
        for section in allSections {
            for model in section.models {
                let assetId = model.asset.localIdentifier
                if let cacheDecision = cacheService.getSwipeDecision(id: assetId) {
                    let photoDecision: PhotoSwipeDecision = cacheDecision ? .keep : .delete
                    loadedDecisions[assetId] = photoDecision
                }
            }
        }
        
        swipeDecisions = loadedDecisions
        print("SWIPE:RESULTS - Loaded \(loadedDecisions.count) existing swipe decisions")
    }
    
    private func clearSwipeDecisions(for deletedIdentifiers: [String]) {
        for identifier in deletedIdentifiers {
            swipeDecisions.removeValue(forKey: identifier)
            cacheService.deleteSwipeDecision(id: identifier)
        }
        print("SWIPE:RESULTS - Cleared swipe decisions for \(deletedIdentifiers.count) deleted photos")
    }
    
    func getSectionsForAssetIdentifiers(_ assetIdentifiers: [String]) -> [MediaCleanerServiceSection] {
        let identifierSet = Set(assetIdentifiers)
        
        // Получаем все доступные секции
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        // Фильтруем модели, оставляя только нужные asset identifiers
        let filteredSections = allSections.compactMap { section -> MediaCleanerServiceSection? in
            let filteredModels = section.models.filter { model in
                identifierSet.contains(model.asset.localIdentifier)
            }
            
            // Возвращаем секцию только если в ней есть нужные модели
            guard !filteredModels.isEmpty else { return nil }
            
            return MediaCleanerServiceSection(
                kind: section.kind,
                models: filteredModels
            )
        }
        
        print("SWIPE:RESULTS - Created \(filteredSections.count) filtered sections from \(assetIdentifiers.count) asset identifiers")
        return filteredSections
    }
    
    private func setupBindings() {
        mediaCleanerService.countsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] counts in
                guard let self = self else { return }
                
                self.similarCount = counts.similar
                self.blurredCount = counts.blurred
                self.duplicatesCount = counts.duplicates
                self.screenshotsCount = counts.screenshots
            }
            .store(in: &cancellables)
        
        mediaCleanerService.megabytesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] megabytes in
                guard let self = self else { return }
                
                self.similarMegabytes = megabytes.similar
                self.blurredMegabytes = megabytes.blurred
                self.duplicatesMegabytes = megabytes.duplicates
                self.screenshotsMegabytes = megabytes.screenshots
            }
            .store(in: &cancellables)
        
        mediaCleanerService.similarPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.similarPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.blurredPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.blurredPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.duplicatesPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.duplicatesPreview, on: self)
            .store(in: &cancellables)
        
        mediaCleanerService.screenshotsPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.screenshotsPreview, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Private Helper Methods
    
    func updateTotalSwipeDecisionsCount() {
        print("UPDATE:COUNT:TEST - updateTotalSwipeDecisionsCount() called")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                print("UPDATE:COUNT:TEST - self is nil in updateTotalSwipeDecisionsCount")
                return 
            }
            print("UPDATE:COUNT:TEST - About to call getTotalSwipeDecisionsForDeletion()")
            let newCount = self.cacheService.getTotalSwipeDecisionsForDeletion()
            print("UPDATE:COUNT:TEST - getTotalSwipeDecisionsForDeletion() returned: \(newCount)")
            print("UPDATE:COUNT:TEST - Current totalSwipeDecisionsForDeletion: \(self.totalSwipeDecisionsForDeletion)")
            
            if self.totalSwipeDecisionsForDeletion != newCount {
                print("UPDATE:COUNT:TEST - Count changed from \(self.totalSwipeDecisionsForDeletion) to \(newCount)")
                self.totalSwipeDecisionsForDeletion = newCount
                print("SWIPE:TOTAL:UPDATE - Updated totalSwipeDecisionsForDeletion to \(newCount)")
                print("UPDATE:COUNT:TEST - Updated @Published totalSwipeDecisionsForDeletion to \(newCount)")
            } else {
                print("UPDATE:COUNT:TEST - Count unchanged: \(newCount)")
            }
        }
    }
    
    private func getTotalSavedInCache() -> Int {
        // Получаем все swipe decisions из cache и считаем сохраненные (true)
        let allSections = [
            getSections(for: .image(.similar)),
            getSections(for: .image(.blurred)),
            getSections(for: .image(.duplicates)),
            getSections(for: .image(.screenshots))
        ].flatMap { $0 }
        
        var savedCount = 0
        for section in allSections {
            for model in section.models {
                let assetId = model.asset.localIdentifier
                if let cacheDecision = cacheService.getSwipeDecision(id: assetId), cacheDecision == true {
                    savedCount += 1
                }
            }
        }
        
        return savedCount
    }
}

// MARK: - SwipeResultsButtonStyle

struct SwipeResultsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct SmartCleanView_Previews: PreviewProvider {
    static var previews: some View {
        SmartCleanView(isPaywallPresented: .constant(false))
    }
}

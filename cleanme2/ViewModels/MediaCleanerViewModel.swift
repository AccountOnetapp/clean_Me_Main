//
//  MediaCleanerViewModel.swift
//  cleanme2
//
//  Created by AI Assistant on 10.08.25.
//

import Foundation
import SwiftUI
import Combine
import Photos

@MainActor
final class MediaCleanerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var scanningState: ScanningState = .idle
    @Published var scanProgress: Double = 0.0
    @Published var selectedTab: TabType = .clean
    @Published var isPro = false
    
    // MARK: - Media Cleaner Properties
    @Published var progress: MediaCleanerServiceProgress = MediaCleanerServiceProgress(type: .image(.similar), index: 0, value: 0, isFinished: false)
    @Published var counts: MediaCleanerServiceCounts<Int> = MediaCleanerServiceCounts<Int>()
    @Published var megabytes: MediaCleanerServiceCounts<Double> = MediaCleanerServiceCounts<Double>()
    @Published var previews: MediaCleanerServicePreviews = MediaCleanerServicePreviews(_similar: nil, _duplicates: nil, _blurred: nil, _screenshots: nil, _videos: nil)
    @Published var mediaWasDeleted: MediaCleanerServiceType = .image(.similar)
    
    // Individual preview properties
    @Published var similarPreview: UIImage? = nil
    @Published var blurredPreview: UIImage? = nil
    @Published var duplicatesPreview: UIImage? = nil
    @Published var screenshotsPreview: UIImage? = nil
    @Published var videosPreview: UIImage? = nil
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var scanTimer: Timer?
    private let mediaCleanerService: MediaCleanerService = MediaCleanerServiceImpl.shared
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to progress updates
        mediaCleanerService.progressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
        
        // Subscribe to counts updates
        mediaCleanerService.countsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.counts, on: self)
            .store(in: &cancellables)
        
        // Subscribe to megabytes updates
        mediaCleanerService.megabytesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.megabytes, on: self)
            .store(in: &cancellables)
        
        // Subscribe to previews updates
        mediaCleanerService.previewsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.previews, on: self)
            .store(in: &cancellables)
        
        // Subscribe to media deletion events
        mediaCleanerService.mediaWasDeletedPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.mediaWasDeleted, on: self)
            .store(in: &cancellables)
        
        // Subscribe to individual preview updates
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
        
        mediaCleanerService.videosPreviewPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.videosPreview, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Tab Types
    enum TabType: String, CaseIterable {
        case clean = "Clean"
        case dashboard = "Dashboard"
        case star = "Star"
        case safeFolder = "Safe Folder"
        case settings = "Settings"
        
        var iconName: String {
            switch self {
            case .clean: return "paintbrush"
            case .dashboard: return "square.grid.2x2"
            case .star: return "sparkles"
            case .safeFolder: return "folder"
            case .settings: return "gearshape"
            }
        }
    }
    
    // MARK: - Computed Properties
    var categoryGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
    
    var totalFilesText: String {
        switch scanningState {
        case .idle:
            return "7 159 files • 110.18 Gb will be cleaned"
        case .scanning:
            return "Scanning..."
        case .completed:
            return "7 159 files • 110.18 Gb will be cleaned"
        }
    }
    
    // MARK: - Public Methods
    
    // MARK: - Media Cleaner Methods
    func checkPhotoLibraryPermission() -> PHAuthorizationStatus {
        return mediaCleanerService.checkAuthStatus()
    }
    
    func requestPhotoLibraryPermission() {
        mediaCleanerService.requestAuthorization { [weak self] status in
            Task { @MainActor in
                if status == .authorized {
                    self?.startScanning()
                }
            }
        }
    }
    
    func startScanning() {
        guard case .idle = scanningState else { return }
        
        scanningState = .scanning(progress: 0.0)
        scanProgress = 0.0
        
        // Start actual media scanning
        Task.detached {
            await self.mediaCleanerService.scanAllImages()
            await self.mediaCleanerService.scanVideos()
        }
        
        // Monitor progress from the service
        mediaCleanerService.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.scanProgress = progress.value
                self?.scanningState = progress.isFinished ? .completed : .scanning(progress: progress.value)
            }
            .store(in: &cancellables)
    }
    
    func getMedia(for type: MediaCleanerServiceType) -> [MediaCleanerServiceSection] {
        return mediaCleanerService.getMedia(type)
    }
    
    func deleteAssets(_ assets: Set<PHAsset>, completion: @escaping (Bool) -> Void) {
        mediaCleanerService.delete(assets: assets, completion: completion)
    }
    
    func resetToIdle() {
        scanTimer?.invalidate()
        scanTimer = nil
        scanningState = .idle
        scanProgress = 0.0
    }
}

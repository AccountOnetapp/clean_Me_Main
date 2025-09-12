import Foundation
import Photos
import UIKit
import Combine

protocol MediaCleanerService {
    var previewsPublisher: AnyPublisher<MediaCleanerServicePreviews, Never> { get }
    var countsPublisher: AnyPublisher<MediaCleanerServiceCounts<Int>, Never> { get }
    var megabytesPublisher: AnyPublisher<MediaCleanerServiceCounts<Double>, Never> { get }
    var progressPublisher: AnyPublisher<MediaCleanerServiceProgress, Never> { get }
    var mediaWasDeletedPublisher: AnyPublisher<MediaCleanerServiceType, Never> { get }
    
    // Individual preview publishers
    var similarPreviewPublisher: AnyPublisher<UIImage?, Never> { get }
    var blurredPreviewPublisher: AnyPublisher<UIImage?, Never> { get }
    var duplicatesPreviewPublisher: AnyPublisher<UIImage?, Never> { get }
    var screenshotsPreviewPublisher: AnyPublisher<UIImage?, Never> { get }
    var videosPreviewPublisher: AnyPublisher<UIImage?, Never> { get }

    func checkAuthStatus() -> PHAuthorizationStatus
    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void)

    func scanAllImages()
    func scanVideos()
    func resetData()
    func getMedia(_ type: MediaCleanerServiceType) -> [MediaCleanerServiceSection]

    func delete(assets: Set<PHAsset>, completion: @escaping (Bool) -> Void)
    func deleteAssets(localIdentifiers: [String], completion: @escaping (Result<[String], Error>) -> Void)
    func updateCountsAndPreviews()
}

final class MediaCleanerServiceImpl: NSObject, PHPhotoLibraryChangeObserver, MediaCleanerService {
    static let shared: MediaCleanerServiceImpl = {
        print("SCAN:TEST - Creating MediaCleanerServiceImpl.shared instance")
        let instance = MediaCleanerServiceImpl(
            photoLibrary: PHPhotoLibrary.shared(),
            imageProcessor: ImageProcessorImpl(),
            imageManager: ImageManager(),
            cacheService: MediaCleanerCacheServiceImpl.shared
        )
        print("SCAN:TEST - MediaCleanerServiceImpl.shared instance created")
        return instance
    }()

    private let imageQueue = DispatchQueue(label: "MediaCleanerServiceImageQueue", qos: .userInteractive)
    private let blurrQueue = DispatchQueue(label: "MediaCleanerServiceBlurrQueue", qos: .userInteractive)
    private let dupliQueue = DispatchQueue(label: "MediaCleanerServiceDupliQueue", qos: .userInteractive)
    private let videoQueue = DispatchQueue(label: "MediaCleanerServiceVideoQueue", qos: .userInteractive)

    private let photoLibrary: PHPhotoLibrary
    private let cachingImageManager: ImageManager

    private var imagesFetchResult: PHFetchResult<PHAsset>?
    private var videoFetchRsult: PHFetchResult<PHAsset>?

    private var similar: Set<MediaCleanerServiceModel> = [] { didSet {
        counts.set(count: similar.count, for: .image(.similar))
        print("SCAN:TEST - Sending counts update: similar=\(similar.count), total=\(counts.total)")
        countsSubject.send(counts)
    }}
    private var duplicates: Set<MediaCleanerServiceModel> = [] { didSet {
        counts.set(count: duplicates.count, for: .image(.duplicates))
        print("SCAN:TEST - Sending counts update: duplicates=\(duplicates.count), total=\(counts.total)")
        countsSubject.send(counts)
    }}
    private var blurred: Set<MediaCleanerServiceModel> = [] { didSet {
        counts.set(count: blurred.count, for: .image(.blurred))
        print("SCAN:TEST - Sending counts update: blurred=\(blurred.count), total=\(counts.total)")
        countsSubject.send(counts)
    }}
    private var screenshots: Set<MediaCleanerServiceModel> = [] { didSet {
        counts.set(count: screenshots.count, for: .image(.screenshots))
        print("SCAN:TEST - Sending counts update: screenshots=\(screenshots.count), total=\(counts.total)")
        countsSubject.send(counts)
    }}
    private var videos: Set<MediaCleanerServiceModel> = [] { didSet {
        counts.set(count: videos.count, for: .video)
        print("SCAN:TEST - Sending counts update: videos=\(videos.count), total=\(counts.total)")
        countsSubject.send(counts)
    }}
    private var audios: Set<MediaCleanerServiceModel> = [] { didSet {
        counts.set(count: audios.count, for: .audio)
        countsSubject.send(counts)
    }}

    private let _imageProgress = MediaCleanerServiceProgress.startImages

    /// Поток превью для похожих изображений
    private let _similarPreview = CurrentValueSubject<UIImage?, Never>(nil)
    /// Поток превью для размытых изображений
    private let _blurredPreview = CurrentValueSubject<UIImage?, Never>(nil)
    /// Поток превью для дубликатов
    private let _duplicatesPreview = CurrentValueSubject<UIImage?, Never>(nil)
    /// Поток превью для скриншотов
    private let _screenshotsPreview = CurrentValueSubject<UIImage?, Never>(nil)
    /// Поток превью для видеофайлов
    private let _videosPreview = CurrentValueSubject<UIImage?, Never>(nil)

    private let imageProcessor: ImageProcessor
    private let cacheService: MediaCleanerCacheService

    // MARK: - Life cycle

    init(
        photoLibrary: PHPhotoLibrary,
        imageProcessor: ImageProcessor,
        imageManager: ImageManager,
        cacheService: MediaCleanerCacheService
    ) {
        print("SCAN:TEST - MediaCleanerServiceImpl init started")
        self.photoLibrary = photoLibrary
        self.imageProcessor = imageProcessor
        self.cachingImageManager = imageManager
        self.cacheService = cacheService
        super.init()
        photoLibrary.register(self)
        print("SCAN:TEST - MediaCleanerServiceImpl init completed")
        print("SCAN:TEST - Initial progress value: \(progressSubject.value.value)")
        print("SCAN:TEST - Initial counts total: \(countsSubject.value.total)")
    }

    deinit {
        photoLibrary.unregisterChangeObserver(self)
    }

    // MARK: - MediaCleanerService conformance
    
    // Private subjects
    private let progressSubject = CurrentValueSubject<MediaCleanerServiceProgress, Never>(
        MediaCleanerServiceProgress(type: .image(.similar), index: 1, value: 0, isFinished: false)
    )
    private let countsSubject = CurrentValueSubject<MediaCleanerServiceCounts<Int>, Never>(
        MediaCleanerServiceCounts<Int>()
    )
    private let megabytesSubject = CurrentValueSubject<MediaCleanerServiceCounts<Double>, Never>(
        MediaCleanerServiceCounts<Double>()
    )
    private let previewsSubject = CurrentValueSubject<MediaCleanerServicePreviews, Never>(
        MediaCleanerServicePreviews(_similar: nil, _duplicates: nil, _blurred: nil, _screenshots: nil, _videos: nil)
    )
    private let mediaWasDeletedSubject = CurrentValueSubject<MediaCleanerServiceType, Never>(
        MediaCleanerServiceType.image(.similar)
    )
    
    // Public publishers
    var progressPublisher: AnyPublisher<MediaCleanerServiceProgress, Never> {
        print("SCAN:TEST - progressPublisher accessed, current value: \(progressSubject.value.value)")
        return progressSubject.eraseToAnyPublisher()
    }
    var countsPublisher: AnyPublisher<MediaCleanerServiceCounts<Int>, Never> {
        print("SCAN:TEST - countsPublisher accessed, current total: \(countsSubject.value.total)")
        return countsSubject.eraseToAnyPublisher()
    }
    var megabytesPublisher: AnyPublisher<MediaCleanerServiceCounts<Double>, Never> {
        print("SCAN:TEST - megabytesPublisher accessed, current total: \(megabytesSubject.value.total)")
        return megabytesSubject.eraseToAnyPublisher()
    }
    var previewsPublisher: AnyPublisher<MediaCleanerServicePreviews, Never> {
        print("SCAN:TEST - previewsPublisher accessed")
        return previewsSubject.eraseToAnyPublisher()
    }
    var mediaWasDeletedPublisher: AnyPublisher<MediaCleanerServiceType, Never> {
        mediaWasDeletedSubject.eraseToAnyPublisher()
    }
    
    // Individual preview publishers
    var similarPreviewPublisher: AnyPublisher<UIImage?, Never> {
        _similarPreview.eraseToAnyPublisher()
    }
    var blurredPreviewPublisher: AnyPublisher<UIImage?, Never> {
        _blurredPreview.eraseToAnyPublisher()
    }
    var duplicatesPreviewPublisher: AnyPublisher<UIImage?, Never> {
        _duplicatesPreview.eraseToAnyPublisher()
    }
    var screenshotsPreviewPublisher: AnyPublisher<UIImage?, Never> {
        _screenshotsPreview.eraseToAnyPublisher()
    }
    var videosPreviewPublisher: AnyPublisher<UIImage?, Never> {
        _videosPreview.eraseToAnyPublisher()
    }
    
    // Computed properties for backward compatibility
    var progress: MediaCleanerServiceProgress { progressSubject.value }
    var counts: MediaCleanerServiceCounts<Int> { countsSubject.value }
    var megabytes: MediaCleanerServiceCounts<Double> { megabytesSubject.value }
    var previews: MediaCleanerServicePreviews { previewsSubject.value }
    var mediaWasDeleted: MediaCleanerServiceType { mediaWasDeletedSubject.value }

    func checkAuthStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            completion(status)
        }
    }

    func scanAllImages() {
        print("SCAN:TEST - MediaCleanerService.scanAllImages() called")
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let imageFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        self.imagesFetchResult = imageFetchResult
        let total = imageFetchResult.count
        print("SCAN:TEST - Found \(total) images to process")
        
        // Если нет изображений, сразу устанавливаем прогресс 100%
        if total == 0 {
            print("SCAN:TEST - No images found, setting progress to 100%")
            let completedProgress = MediaCleanerServiceProgress(
                type: .image,
                index: 0,
                value: 1.0,
                isFinished: true
            )
            DispatchQueue.main.async {
                print("SCAN:TEST - Sending completed progress for empty image scan: 1.0")
                self.progressSubject.send(completedProgress)
            }
            return
        }

        let duplicatesSize = CGSize(width: 1, height: 1)
        let duplicatesRequestOptions = PHImageRequestOptions()
        duplicatesRequestOptions.deliveryMode = .fastFormat
        duplicatesRequestOptions.resizeMode = .fast

        let imageProcessor = self.imageProcessor
//        let progress = self._imageProgress
        let imageManager = self.cachingImageManager
        let imageQueue = self.imageQueue
        let dupliQueue = self.dupliQueue
        let blurrQueue = self.blurrQueue

//        let megabytes = self.megabytes

        let cacheService = self.cacheService

        var similarPreviewIndexThreshold = 0 // similarPreviewIndexThreshold
        var screenshotPreviewIndexThreshold = 0 // screenshotPreviewIndexThreshold
        var duplicatesPreviewIndexThreshold = 0 // duplicatesPreviewIndexThreshold
        var blurredPreviewIndexThreshold = 0 // blurredPreviewIndexThreshold

        func getPreview(
            _ asset: PHAsset,
            delivery: PHImageRequestOptionsDeliveryMode = .highQualityFormat,
            resize: PHImageRequestOptionsResizeMode = .exact,
            completion: @escaping (UIImage?) -> Void
        ) {
            getPhotoPreview(asset, delivery: delivery, resize: resize, completion: completion)
        }
        func insertedSimilar(_ model: MediaCleanerServiceModel) -> Bool {
            similar.insert(model).inserted
        }
        func insertedDuplicates(_ model: MediaCleanerServiceModel) -> Bool {
            duplicates.insert(model).inserted
        }
        func insertedBlurred(_ model: MediaCleanerServiceModel) -> Bool {
            blurred.insert(model).inserted
        }
        func insertedScreenshots(_ model: MediaCleanerServiceModel) -> Bool {
            screenshots.insert(model).inserted
        }

        var prevSimilarModel: MediaCleanerServiceModel?
        var prevDuplicateModel: MediaCleanerServiceModel?
        var prevDuplicateImage: UIImage?

        imageQueue.async {
            imageFetchResult.enumerateObjects { asset, index, _ in
                let newProgress = MediaCleanerServiceProgress(
                    type: .image,
                    index: index,
                    value: Double(index + 1) / Double(total),
                    isFinished: index + 1 == total
                )
                
                if index % 50 == 0 || index == total - 1 {
                    print("SCAN:TEST - Processing image \(index + 1)/\(total), progress: \(newProgress.value)")
                }
                
                DispatchQueue.main.async {
                    print("SCAN:TEST - Sending progress update: \(newProgress.value)")
                    self.progressSubject.send(newProgress)
                }
                let commonModel = MediaCleanerServiceModel(imageManager: imageManager, asset: asset, index: index)

                // MARK: - Finding duplicates

                if let (isDuplicate, equality) = cacheService.getDuplicate(id: commonModel.asset.localIdentifier) {
                    if isDuplicate {
                        commonModel.equality = equality
                        if insertedDuplicates(commonModel) {
                            self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.duplicates))
                        }
                        if self._duplicatesPreview.value == nil || index > duplicatesPreviewIndexThreshold || index == total - 1 {
                            duplicatesPreviewIndexThreshold = index + total / 20
                            getPreview(
                                asset,
                                delivery: self._duplicatesPreview.value == nil ? .opportunistic : .highQualityFormat,
                                resize: .fast
                            ) { image in
                                if let image = image {
                                    self.updatePreview(image: image, for: .image(.duplicates))
                                }
                            }
                        }
                    }
                } else {
                    imageManager.requestImage(
                        for: asset,
                        targetSize: duplicatesSize,
                        contentMode: .aspectFill,
                        options: duplicatesRequestOptions
                    ) { image, options in
                        dupliQueue.async {
                            if let image = image {
                                if
                                    let prevDuplicateModel = prevDuplicateModel,
                                    let prevData = prevDuplicateImage?.pngData(),
                                    let curData = image.pngData(),
                                    prevData == curData
                                {
                                    commonModel.equality = prevDuplicateModel.equality
                                    cacheService.setDuplicate(
                                        id: commonModel.asset.localIdentifier,
                                        value: true,
                                        equality: prevDuplicateModel.equality
                                    )
                                    cacheService.setDuplicate(
                                        id: prevDuplicateModel.asset.localIdentifier,
                                        value: true,
                                        equality: prevDuplicateModel.equality
                                    )
                                    if insertedDuplicates(prevDuplicateModel) {
                                        self.addMegabytes(count: prevDuplicateModel.asset.fakeSize, to: .image(.duplicates))
                                    }
                                    if insertedDuplicates(commonModel) {
                                        self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.duplicates))
                                    }
                                    if self._duplicatesPreview.value == nil || index > duplicatesPreviewIndexThreshold || index == total - 1 {
                                        duplicatesPreviewIndexThreshold = index + total / 20
                                        getPreview(
                                            asset,
                                            delivery: self._duplicatesPreview.value == nil ? .opportunistic : .highQualityFormat,
                                            resize: .fast
                                        ) { image in
                                            if let image = image {
                                                self.updatePreview(image: image, for: .image(.duplicates))
                                            }
                                        }
                                    }
                                } else {
                                    commonModel.equality = commonModel.asset.creationDate?.timeIntervalSince1970 ?? 0
                                    if let prevDuplicateModel = prevDuplicateModel {
                                        if cacheService.getDuplicate(id: prevDuplicateModel.asset.localIdentifier) == nil {
                                            cacheService.setDuplicate(
                                                id: prevDuplicateModel.asset.localIdentifier,
                                                value: false,
                                                equality: prevDuplicateModel.asset.creationDate?.timeIntervalSince1970 ?? 0
                                            )
                                        }
                                    }
                                }
                                prevDuplicateModel = commonModel
                                prevDuplicateImage = image
                            }
                        }
                    }
                }

                // MARK: - Similar and screenshots

                if let prevModel = prevSimilarModel {
                    if
                        let location1 = prevModel.asset.location,
                        let location2 = asset.location,
                        let date1 = prevModel.asset.creationDate,
                        let date2 = asset.creationDate,
                        abs(date2.timeIntervalSince1970 - date1.timeIntervalSince1970) < 5,
                        location1.distance(from: location2) < 1
                    {
                        commonModel.similarity = prevModel.similarity
                        if insertedSimilar(prevModel) {
                            self.addMegabytes(count: prevModel.asset.fakeSize, to: .image(.similar))
                        }
                        if insertedSimilar(commonModel) {
                            self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.similar))
                        }
                        if self._similarPreview.value == nil || index > similarPreviewIndexThreshold || index == total - 1 {
                            similarPreviewIndexThreshold = index + total / 20
                            getPreview(asset, resize: .fast) { image in
                                if let image = image {
                                    self.updatePreview(image: image, for: .image(.similar))
                                }
                            }
                        }
                    } else {
                        commonModel.similarity = index
                    }
                }
                prevSimilarModel = commonModel

                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    if insertedScreenshots(commonModel) {
                        self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.screenshots))
                    }
                    if self._screenshotsPreview.value == nil || index > screenshotPreviewIndexThreshold || index == total - 1 {
                        screenshotPreviewIndexThreshold = index + total / 20
                        getPreview(asset, resize: .fast) { image in
                            if let image = image {
                                self.updatePreview(image: image, for: .image(.screenshots))
                            }
                        }
                    }
                }

                // MARK: - Detecting blurred

                if let isBlurred = cacheService.getBlurred(id: commonModel.asset.localIdentifier) {
                    if isBlurred {
                        if insertedBlurred(commonModel) {
                            self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.blurred))
                        }
                        if self._blurredPreview.value == nil || index > blurredPreviewIndexThreshold || index == total - 1 {
                            blurredPreviewIndexThreshold = index + total / 20
                            getPreview(commonModel.asset, resize: .fast) { image in
                                if let image = image {
                                    self.updatePreview(image: image, for: .image(.blurred))
                                }
                            }
                        }
                    }
                } else {
//                    if _blurrCheckIsAllowed.value {
                        getPreview(commonModel.asset) { image in
                            blurrQueue.async {
//                                if _blurrCheckIsAllowed.value {
                                    if let image = image {
                                        if imageProcessor.isBlurry(image) {
                                            if insertedBlurred(commonModel) {
                                                self.addMegabytes(count: commonModel.asset.fakeSize, to: .image(.blurred))
                                            }
                                            self.updatePreview(image: image, for: .image(.blurred))
                                            cacheService.setBlurred(id: asset.localIdentifier, value: true)
                                        } else {
                                            cacheService.setBlurred(id: asset.localIdentifier, value: false)
                                        }
//                                    }
                                }
                            }
                        }
//                    }
                }
            }
        }


        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            print("TEST: similar = \(self.similar.count)")
            print("TEST: duplicates = \(self.duplicates.count)")
            print("TEST: blurred = \(self.blurred.count)")
            print("TEST: screenshots = \(self.screenshots.count)")
        }
    }

    func scanVideos() {
        print("SCAN:TEST - MediaCleanerService.scanVideos() called")
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videoFetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        self.videoFetchRsult = videoFetchResult
        print("SCAN:TEST - Found \(videoFetchResult.count) videos to process")
        
        // Если нет видео, это нормально - видео сканирование не влияет на основной прогресс
        if videoFetchResult.count == 0 {
            print("SCAN:TEST - No videos found, this is normal")
            return
        }

        let previewSide = (UIScreen.main.bounds.width - 40) / 2
        let previewSize = CGSize(width: previewSide, height: previewSide)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        let previewIndicies: Set<Int> = {
            var out: Set<Int> = []
            let step = videoFetchResult.count / 3
            var index = 0
            while index < videoFetchResult.count {
                out.insert(index)
                index += step
            }
            out.insert(videoFetchResult.count - 1)
            return out
        }()

        let imageManager = self.cachingImageManager
//        let megabytes = self.megabytes
        let _ = self._videosPreview

        func insertedVideo(_ model: MediaCleanerServiceModel) -> Bool {
            videos.insert(model).inserted
        }
        videoQueue.async {
            videoFetchResult.enumerateObjects { asset, index, _ in
                let model = MediaCleanerServiceModel(imageManager: imageManager, asset: asset, index: index)
                if insertedVideo(model) {
                    self.addMegabytes(count: model.asset.fakeSize, to: .video)
                }
                if previewIndicies.contains(index) {
                    imageManager.requestImage(
                        for: asset,
                        targetSize: previewSize,
                        contentMode: .aspectFill,
                        options: requestOptions
                    ) { image, _ in
                        if let image = image {
                            self.updatePreview(image: image, for: .video)
                        }
                    }
                }
            }
        }
    }

    func resetData() {
        print("SCAN:TEST - Resetting all data before new scan.")
        // Сброс всех Subjects к их начальным значениям
        progressSubject.send(MediaCleanerServiceProgress(type: .image(.similar), index: 1, value: 0, isFinished: false))
        countsSubject.send(MediaCleanerServiceCounts<Int>())
        megabytesSubject.send(MediaCleanerServiceCounts<Double>())
        previewsSubject.send(MediaCleanerServicePreviews(_similar: nil, _duplicates: nil, _blurred: nil, _screenshots: nil, _videos: nil))
        
        // Также сбросьте все ваши локальные Set<MediaCleanerServiceModel>
        similar.removeAll()
        duplicates.removeAll()
        blurred.removeAll()
        screenshots.removeAll()
        videos.removeAll()
    }
    
    func getMedia(_ type: MediaCleanerServiceType) -> [MediaCleanerServiceSection] {
        let arr: [MediaCleanerServiceSection] = {
            switch type {
            case .image(let imageType):
                switch imageType {
                case .duplicates:
                    if duplicates.isEmpty { return [] }
                    return duplicates.equalitySections
                case .similar:
                    if similar.isEmpty { return [] }
                    return similar.similaritySections
                case .screenshots:
                    if screenshots.isEmpty { return [] }
                    return screenshots.dateSections
                case .blurred:
                    if blurred.isEmpty { return [] }
                    return blurred.dateSections
                }
            case .video:
                if videos.isEmpty { return [] }
                return videos.dateSections
            case .audio:
                if audios.isEmpty { return [] }
                return audios.dateSections
            }
        }()

        return arr
    }

    func delete(assets: Set<PHAsset>, completion: @escaping (Bool) -> Void) {
        photoLibrary.performChanges({
            PHAssetChangeRequest.deleteAssets(Array(assets) as NSArray)
        }, completionHandler: { result, error in
            completion(result)
        })
    }

    // Реализация нового метода
    func deleteAssets(localIdentifiers: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        
        // Преобразуем PHFetchResult в Swift массив.
        let assetsArray = assetsToDelete.objects(at: IndexSet(0..<assetsToDelete.count))
        
        // Явно преобразуем Swift массив в NSArray для API Photos Framework.
        let assetsToDeleteAsNSArray = assetsArray as NSArray
        
        photoLibrary.performChanges({
            // Используем преобразованный NSArray для метода удаления.
            PHAssetChangeRequest.deleteAssets(assetsToDeleteAsNSArray)
        }) { success, error in
            if success {
                completion(.success(localIdentifiers))
            } else {
                completion(.failure(error ?? NSError(domain: "DeleteAssetsError", code: -1, userInfo: nil)))
            }
        }
    }
    
    func updateCountsAndPreviews() {
        scanAllImages()
        scanVideos()
    }
    
    // MARK: - PHPhotoLibraryChangeObserver conformance

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        if let imageFetch = imagesFetchResult, let info = changeInstance.changeDetails(for: imageFetch) {
            if !info.insertedObjects.isEmpty {
                cacheService.deleteAllDuplicates()
            }
            for object in info.removedObjects {
                if let first = similar.first(where: { $0.asset.isEqual(object) }) {
                    if similar.remove(first) != nil {
                        cacheService.deleteSize(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.image(.similar))
                    }
                }
                if let first = duplicates.first(where: { $0.asset.isEqual(object) }) {
                    if duplicates.remove(first) != nil {
                        cacheService.deleteDuplicate(id: first.asset.localIdentifier)
                        let rest = duplicates.compactMap { $0.equality == first.equality ? $0 : nil }
                        if rest.count == 1 {
                            let another = rest.first!
                            duplicates.remove(another)
                            cacheService.deleteDuplicate(id: another.asset.localIdentifier)
                        }
                        mediaWasDeletedSubject.send(.image(.duplicates))
                    }
                }
                if let first = blurred.first(where: { $0.asset.isEqual(object) }) {
                    if blurred.remove(first) != nil {
                        cacheService.deleteBlurred(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.image(.blurred))
                    }
                }
                if let first = screenshots.first(where: { $0.asset.isEqual(object) }) {
                    if screenshots.remove(first) != nil {
                        cacheService.deleteSize(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.image(.screenshots))
                    }
                }
            }
        }
        if let videoFetch = videoFetchRsult, let info = changeInstance.changeDetails(for: videoFetch) {
            for object in info.removedObjects {
                if let first = videos.first(where: { $0.asset.isEqual(object) }) {
                    if videos.remove(first) != nil {
                        cacheService.deleteSize(id: first.asset.localIdentifier)
                        mediaWasDeletedSubject.send(.video)
                    }
                }
            }
        }
    }

    // MARK: - Private
    
    private func addMegabytes(count: Double, to type: MediaCleanerServiceType) {
        let currentMegabytes = megabytesSubject.value
        currentMegabytes.add(count: count, to: type)
        megabytesSubject.send(currentMegabytes)
    }
    
    private func updatePreview(image: UIImage, for type: MediaCleanerServiceType) {
        let currentPreviews = previewsSubject.value
        let newPreviews: MediaCleanerServicePreviews
        
        switch type {
        case .image(let imageType):
            switch imageType {
            case .similar:
                _similarPreview.send(image)
                newPreviews = MediaCleanerServicePreviews(
                    _similar: image,
                    _duplicates: currentPreviews.duplicates,
                    _blurred: currentPreviews.blurred,
                    _screenshots: currentPreviews.screenshots,
                    _videos: currentPreviews.videos
                )
            case .duplicates:
                _duplicatesPreview.send(image)
                newPreviews = MediaCleanerServicePreviews(
                    _similar: currentPreviews.similar,
                    _duplicates: image,
                    _blurred: currentPreviews.blurred,
                    _screenshots: currentPreviews.screenshots,
                    _videos: currentPreviews.videos
                )
            case .blurred:
                _blurredPreview.send(image)
                newPreviews = MediaCleanerServicePreviews(
                    _similar: currentPreviews.similar,
                    _duplicates: currentPreviews.duplicates,
                    _blurred: image,
                    _screenshots: currentPreviews.screenshots,
                    _videos: currentPreviews.videos
                )
            case .screenshots:
                _screenshotsPreview.send(image)
                newPreviews = MediaCleanerServicePreviews(
                    _similar: currentPreviews.similar,
                    _duplicates: currentPreviews.duplicates,
                    _blurred: currentPreviews.blurred,
                    _screenshots: image,
                    _videos: currentPreviews.videos
                )
            }
        case .video:
            _videosPreview.send(image)
            newPreviews = MediaCleanerServicePreviews(
                _similar: currentPreviews.similar,
                _duplicates: currentPreviews.duplicates,
                _blurred: currentPreviews.blurred,
                _screenshots: currentPreviews.screenshots,
                _videos: image
            )
        case .audio:
            // Audio doesn't have preview images
            return
        }
        
        previewsSubject.send(newPreviews)
    }

    private func getPhotoPreview(
        _ asset: PHAsset,
        delivery: PHImageRequestOptionsDeliveryMode = .highQualityFormat,
        resize: PHImageRequestOptionsResizeMode = .exact,
        completion: @escaping (UIImage?) -> Void
    ) {
        let previewSize = CGSize(width: 130, height: 130)
        let previewRequestOptions = PHImageRequestOptions()
        previewRequestOptions.deliveryMode = delivery
        previewRequestOptions.resizeMode = resize
        cachingImageManager.requestImage(
            for: asset,
            targetSize: previewSize,
            contentMode: .aspectFill,
            options: previewRequestOptions
        ) { image, _ in
            completion(image)
        }
    }

    private func getSize(_ asset: PHAsset, completion: @escaping (Double) -> Void) {
        if let size = cacheService.getSize(id: asset.localIdentifier) {
            completion(size)
        } else {
            let size = asset.megabytesOnDisk
            completion(size)
            cacheService.setSize(id: asset.localIdentifier, value: size)
        }
    }
}

// MARK: - Extensions

extension Set where Element == MediaCleanerServiceModel {

    var dateSections: [MediaCleanerServiceSection] {
        makeDateSections(sortedByIndex)
    }

    var equalitySections: [MediaCleanerServiceSection] {
        makeEqualitySections(sortedByEquality)
    }

    var similaritySections: [MediaCleanerServiceSection] {
        makeSimilaritySections(sortedBySimilarity)
    }

    private var sortedByIndex: [Element] {
        sorted(by: { $0.index < $1.index })
    }

    private var sortedByEquality: [Element] {
        sorted(by: { $0.equality > $1.equality })
    }

    private var sortedBySimilarity: [Element] {
        sorted(by: { $0.similarity < $1.similarity })
    }

    private func makeDateSections(_ sorted: [MediaCleanerServiceModel]) -> [MediaCleanerServiceSection] {
        var out: [MediaCleanerServiceSection] = []
        var models: [MediaCleanerServiceModel] = []
        var prevDate = sorted.first(where: { $0.asset.creationDate != nil })?.asset.creationDate ??  Date(timeIntervalSince1970: 0)
        for (index, model) in sorted.enumerated() {
            if let curDate = model.asset.creationDate {
                if abs(prevDate.timeIntervalSince1970 - curDate.timeIntervalSince1970) > 86400 {
                    if !models.isEmpty {
                        out.append(.init(kind: .date(prevDate == Date(timeIntervalSince1970: 0) ? nil : prevDate), models: models))
                    }
                    models = []
                    prevDate = curDate
                }
            }
            models.append(model)
            if index == sorted.count - 1 && !models.isEmpty {
                out.append(.init(kind: .date(prevDate == Date(timeIntervalSince1970: 0) ? nil : prevDate), models: models))
            }
        }
        return out
    }

    private func makeEqualitySections(_ sorted: [MediaCleanerServiceModel]) -> [MediaCleanerServiceSection] {
        var out: [MediaCleanerServiceSection] = []
        var models: [MediaCleanerServiceModel] = []
        var prevProximity: Double = 0
        for (index, model) in sorted.enumerated() {
            if model.equality != prevProximity {
                if models.count > 1 {
                    out.append(.init(kind: .count, models: models))
                }
                models = []
                prevProximity = model.equality
            }
            models.append(model)
            if index == sorted.count - 1 && models.count > 1 {
                out.append(.init(kind: .count, models: models))
            }
        }
        return out
    }

    private func makeSimilaritySections(_ sorted: [MediaCleanerServiceModel]) -> [MediaCleanerServiceSection] {
        var out: [MediaCleanerServiceSection] = []
        var models: [MediaCleanerServiceModel] = []
        var prevProximity = Int.min
        for (index, model) in sorted.enumerated() {
            if model.similarity > prevProximity {
                if models.count > 1 {
                    out.append(.init(kind: .count, models: models))
                }
                models = []
                prevProximity = model.similarity
            }
            models.append(model)
            if index == sorted.count - 1 && models.count > 1 {
                out.append(.init(kind: .count, models: models))
            }
        }
        return out
    }
}

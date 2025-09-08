import Photos
import UIKit

enum MediaCleanerServiceType: Equatable {
    static let image = Self.image(.duplicates)

    enum ImageType {
        case similar
        case duplicates
        case blurred
        case screenshots
    }

    case image(ImageType)
    case video
    case audio
}

struct MediaCleanerServiceProgress {
    static let startImages = Self(type: .image, index: 0, value: 0, isFinished: false)
    static let startVideos = Self(type: .video, index: 0, value: 0, isFinished: false)

    let type: MediaCleanerServiceType
    let index: Int
    let value: Double
    let isFinished: Bool
}

class MediaCleanerServiceModel: Hashable {
    enum CustomError: Error {
        case noSelf
    }

    static func == (lhs: MediaCleanerServiceModel, rhs: MediaCleanerServiceModel) -> Bool {
        lhs.asset === rhs.asset
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(asset)
    }

    let imageManager: PHCachingImageManager
    let asset: PHAsset
    let index: Int
    var equality: Double = 0
    var similarity = 0

    init(imageManager: PHCachingImageManager, asset: PHAsset, index: Int) {
        self.imageManager = imageManager
        self.asset = asset
        self.index = index
    }

    func getImage(size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        self.imageManager.requestImage(
            for: self.asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            completion(image)
        }
    }
}

struct MediaCleanerServiceSection: Identifiable {
    let id = UUID()
    
    enum Kind {
        case count
        case date(Date?)
        case united(Date?)
    }
    let kind: Kind
    var models: [MediaCleanerServiceModel]
}

class MediaCleanerServiceCounts<Element: Numeric> {
    var similar: Element
    var duplicates: Element
    var blurred: Element
    var screenshots: Element
    var videos: Element
    var audio: Element
    var total: Element

    private let lock = NSLock()

    init(
        similar: Element = 0,
        duplicates: Element = 0,
        blurred: Element = 0,
        screenshots: Element = 0,
        videos: Element = 0,
        audio: Element = 0,
        total: Element = 0
    ) {
        self.similar = similar
        self.duplicates = duplicates
        self.blurred = blurred
        self.screenshots = screenshots
        self.videos = videos
        self.audio = audio
        self.total = total
    }

    func set(count: Element, for type: MediaCleanerServiceType) {
        lock.lock()
        switch type {
        case .image(let imageType):
            switch imageType {
            case .similar:
                similar = (count)
            case .duplicates:
                duplicates = count
            case .blurred:
                blurred = count
            case .screenshots:
                screenshots = count
            }
        case .video:
            videos = count
        case .audio:
            audio = count
        }

        total = similar + duplicates + blurred + screenshots + videos + audio
        lock.unlock()
    }

    func add(count: Element, to type: MediaCleanerServiceType) {
        lock.lock()
        switch type {
        case .image(let imageType):
            switch imageType {
            case .similar:
                let accumulated = similar
                similar = accumulated + count
            case .duplicates:
                let accumulated = duplicates
                duplicates = accumulated + count
            case .blurred:
                let accumulated = blurred
                blurred = accumulated + count
            case .screenshots:
                let accumulated = screenshots
                screenshots = accumulated + count
            }
        case .video:
            let accumulated = videos
            videos = accumulated + count
        case .audio:
            let accumulated = audio
            audio = accumulated + count
        }

        total = similar + duplicates + blurred + screenshots + videos + audio
        lock.unlock()
    }
}

struct MediaCleanerServicePreviews {
    let similar: UIImage?
    let duplicates: UIImage?
    let blurred: UIImage?
    let screenshots: UIImage?
    let videos: UIImage?

    init(
        _similar: UIImage?,
        _duplicates: UIImage?,
        _blurred: UIImage?,
        _screenshots: UIImage?,
        _videos: UIImage?
    ) {
        similar = _similar
        duplicates = _duplicates
        blurred = _blurred
        screenshots = _screenshots
        videos = _videos
    }
}

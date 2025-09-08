//
//  FileSystemStorageManager.swift
//  cleanme2
//
//  Created by AI Assistant on 13.08.25.
//

import Foundation
import UIKit
import AVFoundation
import os.log

// MARK: - File System Storage Manager
class FileSystemStorageManager {
    
    // MARK: - Logging
    private static let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "FileSystemStorage")
    
    // MARK: - Storage Directories
    private static let baseDirectoryName = "SafeStorage"
    private static let photosDirectoryName = "Photos"
    private static let videosDirectoryName = "Videos"
    private static let documentsDirectoryName = "Documents"
    private static let thumbnailsDirectoryName = "Thumbnails"
    
    // MARK: - Directory URLs
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static var baseDirectory: URL {
        documentsDirectory.appendingPathComponent(baseDirectoryName)
    }
    
    static var photosDirectory: URL {
        baseDirectory.appendingPathComponent(photosDirectoryName)
    }
    
    static var videosDirectory: URL {
        baseDirectory.appendingPathComponent(videosDirectoryName)
    }
    
    static var documentsStorageDirectory: URL {
        baseDirectory.appendingPathComponent(documentsDirectoryName)
    }
    
    static var thumbnailsDirectory: URL {
        baseDirectory.appendingPathComponent(thumbnailsDirectoryName)
    }
    
    // MARK: - Initialization
    static func createDirectoriesIfNeeded() throws {
        logger.info("🏗️ Creating storage directories if needed")
        
        let directories = [
            ("Base", baseDirectory),
            ("Photos", photosDirectory),
            ("Videos", videosDirectory),
            ("Documents", documentsStorageDirectory),
            ("Thumbnails", thumbnailsDirectory)
        ]
        
        for (name, directory) in directories {
            let directoryExists = FileManager.default.fileExists(atPath: directory.path)
            
            if directoryExists {
                logger.debug("📁 \(name) directory already exists: \(directory.path)")
            } else {
                logger.info("📁 Creating \(name) directory: \(directory.path)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                logger.info("✅ Successfully created \(name) directory")
            }
        }
        
        logger.info("✅ All storage directories are ready")
    }
    
    // MARK: - Photo Storage
    static func savePhoto(_ imageData: Data, fileName: String? = nil) throws -> (imageURL: URL, thumbnailURL: URL?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let actualFileName = fileName ?? "photo_\(UUID().uuidString).jpg"
        
        logger.info("📸 Starting photo save operation")
        logger.debug("📸 Photo details - FileName: \(actualFileName), Size: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
        
        do {
            try createDirectoriesIfNeeded()
            
            let imageURL = photosDirectory.appendingPathComponent(actualFileName)
            logger.debug("📸 Photo will be saved to: \(imageURL.path)")
            
            // Save original image
            logger.info("💾 Writing original photo file...")
            try imageData.write(to: imageURL)
            let fileSize = FileSystemStorageManager.fileSize(at: imageURL)
            logger.info("✅ Original photo saved successfully - Size on disk: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            
            // Generate and save thumbnail
            var thumbnailURL: URL?
            logger.info("🖼️ Generating photo thumbnail...")
            
            if let thumbnailData = generateThumbnail(from: imageData) {
                let thumbnailFileName = "thumb_\(actualFileName)"
                thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                logger.debug("🖼️ Thumbnail will be saved to: \(thumbnailURL!.path)")
                
                try thumbnailData.write(to: thumbnailURL!)
                let thumbnailFileSize = FileSystemStorageManager.fileSize(at: thumbnailURL!)
                logger.info("✅ Thumbnail saved successfully - Size: \(ByteCountFormatter.string(fromByteCount: thumbnailFileSize, countStyle: .file))")
            } else {
                logger.warning("⚠️ Failed to generate thumbnail for photo")
            }
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("✅ Photo save operation completed in \(String(format: "%.3f", duration))s")
            
            return (imageURL: imageURL, thumbnailURL: thumbnailURL)
            
        } catch {
            logger.error("❌ Photo save failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    static func savePhotoAsync(_ imageData: Data, fileName: String? = nil) async throws -> (imageURL: URL, thumbnailURL: URL?) {
        logger.info("🔄 Starting async photo save operation")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try savePhoto(imageData, fileName: fileName)
                    logger.info("✅ Async photo save completed successfully")
                    continuation.resume(returning: result)
                } catch {
                    logger.error("❌ Async photo save failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Video Storage
    static func saveVideo(_ videoData: Data, fileName: String? = nil) throws -> (videoURL: URL, thumbnailURL: URL?) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let actualFileName = fileName ?? "video_\(UUID().uuidString).mp4"
        
        logger.info("🎥 Starting video save operation")
        logger.debug("🎥 Video details - FileName: \(actualFileName), Size: \(ByteCountFormatter.string(fromByteCount: Int64(videoData.count), countStyle: .file))")
        
        do {
            try createDirectoriesIfNeeded()
            
            let videoURL = videosDirectory.appendingPathComponent(actualFileName)
            logger.debug("🎥 Video will be saved to: \(videoURL.path)")
            
            // Save video file
            logger.info("💾 Writing video file...")
            try videoData.write(to: videoURL)
            let fileSize = FileSystemStorageManager.fileSize(at: videoURL)
            logger.info("✅ Video saved successfully - Size on disk: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            
            // Extract video duration
            let duration = extractVideoDuration(from: videoURL)
            logger.debug("⏱️ Video duration: \(String(format: "%.2f", duration))s")
            
            // Generate thumbnail
            var thumbnailURL: URL?
            logger.info("🖼️ Generating video thumbnail...")
            
            do {
                thumbnailURL = try generateVideoThumbnail(from: videoURL)
                let thumbnailFileSize = FileSystemStorageManager.fileSize(at: thumbnailURL!)
                logger.info("✅ Video thumbnail generated successfully - Size: \(ByteCountFormatter.string(fromByteCount: thumbnailFileSize, countStyle: .file))")
            } catch {
                logger.warning("⚠️ Failed to generate video thumbnail: \(error.localizedDescription)")
                // Continue without thumbnail rather than failing the entire operation
            }
            
            let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("✅ Video save operation completed in \(String(format: "%.3f", totalDuration))s")
            
            return (videoURL: videoURL, thumbnailURL: thumbnailURL)
            
        } catch {
            logger.error("❌ Video save failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Video Metadata Extraction
    static func extractVideoDuration(from videoURL: URL) -> Double {
        logger.debug("⏱️ Extracting video duration from: \(videoURL.lastPathComponent)")
        
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration
        let durationSeconds = duration.seconds.isFinite ? duration.seconds : 0.0
        
        logger.debug("⏱️ Extracted duration: \(String(format: "%.2f", durationSeconds))s")
        
        return durationSeconds
    }
    
    // MARK: - Document Storage
    static func saveDocument(_ documentData: Data, fileName: String) throws -> URL {
        try createDirectoriesIfNeeded()
        
        let documentURL = documentsStorageDirectory.appendingPathComponent(fileName)
        try documentData.write(to: documentURL)
        return documentURL
    }
    
    // MARK: - Data Retrieval
    static func loadImage(from url: URL) -> UIImage? {
        logger.debug("📖 Loading image from: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("⚠️ Image file not found: \(url.path)")
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("❌ Failed to read image data from: \(url.path)")
            return nil
        }
        
        guard let image = UIImage(data: data) else {
            logger.error("❌ Failed to create UIImage from data: \(url.lastPathComponent)")
            return nil
        }
        
        logger.debug("✅ Successfully loaded image - Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        return image
    }
    
    static func loadImageData(from url: URL) -> Data? {
        logger.debug("📖 Loading image data from: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("⚠️ Image file not found: \(url.path)")
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("❌ Failed to read image data from: \(url.path)")
            return nil
        }
        
        logger.debug("✅ Successfully loaded image data - Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        return data
    }
    
    static func loadThumbnail(from url: URL?) -> UIImage? {
        guard let url = url else {
            logger.debug("📖 No thumbnail URL provided")
            return nil
        }
        
        logger.debug("📖 Loading thumbnail from: \(url.lastPathComponent)")
        let thumbnail = loadImage(from: url)
        
        if thumbnail != nil {
            logger.debug("✅ Successfully loaded thumbnail")
        } else {
            logger.warning("⚠️ Failed to load thumbnail")
        }
        
        return thumbnail
    }
    
    // MARK: - File Deletion
    static func deleteFile(at url: URL) throws {
        logger.debug("🗑️ Attempting to delete file: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.debug("ℹ️ File does not exist, skipping deletion: \(url.path)")
            return
        }
        
        let fileSize = fileSize(at: url)
        
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("✅ Successfully deleted file: \(url.lastPathComponent) (Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
        } catch {
            logger.error("❌ Failed to delete file: \(url.lastPathComponent) - Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    static func deletePhotoFiles(imageURL: URL, thumbnailURL: URL?) throws {
        logger.info("🗑️ Starting photo files deletion")
        logger.debug("🗑️ Photo file: \(imageURL.lastPathComponent)")
        
        do {
            try deleteFile(at: imageURL)
            
            if let thumbnailURL = thumbnailURL {
                logger.debug("🗑️ Thumbnail file: \(thumbnailURL.lastPathComponent)")
                try deleteFile(at: thumbnailURL)
            } else {
                logger.debug("ℹ️ No thumbnail to delete")
            }
            
            logger.info("✅ Photo files deletion completed successfully")
        } catch {
            logger.error("❌ Photo files deletion failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    static func deleteVideoFiles(videoURL: URL, thumbnailURL: URL?) throws {
        logger.info("🗑️ Starting video files deletion")
        logger.debug("🗑️ Video file: \(videoURL.lastPathComponent)")
        
        do {
            try deleteFile(at: videoURL)
            
            if let thumbnailURL = thumbnailURL {
                logger.debug("🗑️ Thumbnail file: \(thumbnailURL.lastPathComponent)")
                try deleteFile(at: thumbnailURL)
            } else {
                logger.debug("ℹ️ No thumbnail to delete")
            }
            
            logger.info("✅ Video files deletion completed successfully")
        } catch {
            logger.error("❌ Video files deletion failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - File Size Calculation
    static func fileSize(at url: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return attributes[.size] as? Int64 ?? 0
    }
    
    // MARK: - Thumbnail Generation
    private static func generateThumbnail(from imageData: Data, maxSize: CGFloat = 150) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        let size = image.size
        let aspectRatio = size.width / size.height
        let thumbnailSize: CGSize
        
        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // Use Core Graphics for better performance
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        guard let cgImage = image.cgImage else { return nil }
        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))
        
        guard let thumbnailCGImage = context.makeImage() else { return nil }
        let thumbnail = UIImage(cgImage: thumbnailCGImage)
        
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - Video Thumbnail Generation
    static func generateVideoThumbnail(from videoURL: URL) throws -> URL {
        try createDirectoriesIfNeeded()
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Generate thumbnail at 1 second mark or beginning if video is shorter
        let time = CMTime(seconds: min(1.0, asset.duration.seconds), preferredTimescale: 600)
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let image = UIImage(cgImage: cgImage)
        
        // Resize to thumbnail size
        let thumbnailImage = try resizeImageForThumbnail(image, maxSize: 150)
        
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else {
            throw FileSystemStorageError.thumbnailGenerationFailed
        }
        
        // Save thumbnail
        let thumbnailFileName = "thumb_\(videoURL.lastPathComponent).jpg"
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
        try thumbnailData.write(to: thumbnailURL)
        
        return thumbnailURL
    }
    
    private static func resizeImageForThumbnail(_ image: UIImage, maxSize: CGFloat) throws -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        let thumbnailSize: CGSize
        
        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // Use Core Graphics for better performance
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw FileSystemStorageError.thumbnailGenerationFailed
        }
        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FileSystemStorageError.thumbnailGenerationFailed
        }
        
        guard let cgImage = image.cgImage else {
            throw FileSystemStorageError.thumbnailGenerationFailed
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))
        
        guard let thumbnailCGImage = context.makeImage() else {
            throw FileSystemStorageError.thumbnailGenerationFailed
        }
        
        return UIImage(cgImage: thumbnailCGImage)
    }
    
    // MARK: - Storage Statistics
    static func getStorageStatistics() -> (totalFiles: Int, totalSizeBytes: Int64) {
        let directories = [photosDirectory, videosDirectory, documentsStorageDirectory, thumbnailsDirectory]
        var totalFiles = 0
        var totalSize: Int64 = 0
        
        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalFiles += 1
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return (totalFiles: totalFiles, totalSizeBytes: totalSize)
    }
    
    // MARK: - Cleanup
    static func cleanupOrphanedFiles() throws {
        // This method can be implemented to clean up files that are no longer referenced in Core Data
        // For now, it's a placeholder for future implementation
    }
}

// MARK: - File System Storage Error
enum FileSystemStorageError: LocalizedError {
    case directoryCreationFailed
    case fileWriteFailed
    case fileReadFailed
    case fileNotFound
    case thumbnailGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "Failed to create storage directory"
        case .fileWriteFailed:
            return "Failed to write file to storage"
        case .fileReadFailed:
            return "Failed to read file from storage"
        case .fileNotFound:
            return "File not found in storage"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        }
    }
}

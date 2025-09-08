//
//  MediaCleanerCacheService.swift
//  TectoniumCleaner
//
//  Created by Maksim Polous on 17/05/2023.
//

import Combine
import CoreData
import Foundation
import os.log

// Import the data transfer objects from StoragePerformer

protocol MediaCleanerCacheService {
    func getBlurred(id: String) -> Bool?
    func getDuplicate(id: String) -> (Bool, Double)?
    func getSize(id: String) -> Double?
    
    // Swipe decisions: true = ignored, false = selected for smart cleaning, nil = no decision
    func getSwipeDecision(id: String) -> Bool?
    
    // Get total count of swipe decisions marked for deletion (false value)
    func getTotalSwipeDecisionsForDeletion() -> Int

    func setBlurred(id: String, value: Bool)
    func setDuplicate(id: String, value: Bool, equality: Double)
    func setSize(id: String, value: Double)
    func setSwipeDecision(id: String, ignored: Bool)

    func deleteSize(id: String)
    func deleteBlurred(id: String)
    func deleteDuplicate(id: String)
    func deleteSwipeDecision(id: String)
    func deleteAllDuplicates()
}

final class MediaCleanerCacheServiceImpl: MediaCleanerCacheService {
    static let shared: MediaCleanerCacheServiceImpl = {
        print("SWIPE:DB:TEST - Creating MediaCleanerCacheServiceImpl.shared singleton")
        let instance = MediaCleanerCacheServiceImpl(storagePerformer: StoragePerformerImpl())
        print("SWIPE:DB:TEST - MediaCleanerCacheServiceImpl.shared singleton created")
        return instance
    }()
    
    private let logger = Logger(subsystem: "com.cleanme", category: "MediaCleanerCache")
    private let storagePerformer: StoragePerformer

    private let blurredLock = NSLock()
    private let duplicateLock = NSLock()
    private let sizeLock = NSLock()

    private var blurred: [String: Bool] = [:]
    private var duplicates: [String: (Bool, Double)] = [:]
    private var sizes: [String: Double] = [:]

    private let saveBlurredSubject = PassthroughSubject<Void, Never>()
    private let saveDuplicatesSubject = PassthroughSubject<Void, Never>()
    private let saveSizesSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()
    
    // Operation guards to prevent concurrent operations
    private var isSavingBlurred = false
    private var isSavingDuplicates = false 
    private var isSavingSizes = false

    init(storagePerformer: StoragePerformer) {
        self.storagePerformer = storagePerformer
        self.logger.info("🏗️ MediaCleanerCacheService initialized with Core Data")
        print("SWIPE:DB:TEST - MediaCleanerCacheService init() called - NEW INSTANCE CREATED")

        print("SWIPE:DB:TEST - Preparing caches from database...")
        prepareSizes()
        prepareBlurred()
        prepareDuplicates()

        // Setup throttled saving using Combine
        print("⚙️ [MediaCleanerCacheService] Setting up Combine throttled saving pipelines...")
        
        saveBlurredSubject
            .throttle(for: .seconds(18), scheduler: DispatchQueue.main, latest: true)
            .delay(for: .seconds(6), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔵 [MediaCleanerCacheService] Throttled blurred save triggered (18s throttle + 6s delay)")
                self?.saveBlurred()
            }
            .store(in: &cancellables)

        saveDuplicatesSubject
            .throttle(for: .seconds(18), scheduler: DispatchQueue.main, latest: true)
            .delay(for: .seconds(12), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🟡 [MediaCleanerCacheService] Throttled duplicates save triggered (18s throttle + 12s delay)")
                self?.saveDuplicates()
            }
            .store(in: &cancellables)

        saveSizesSubject
            .throttle(for: .seconds(18), scheduler: DispatchQueue.main, latest: true)
            .delay(for: .seconds(18), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🟢 [MediaCleanerCacheService] Throttled sizes save triggered (18s throttle + 18s delay)")
                self?.saveSizes()
            }
            .store(in: &cancellables)
        
        print("✅ [MediaCleanerCacheService] Initialization completed!")
    }

    // MARK: Get

    func getBlurred(id: String) -> Bool? {
        blurredLock.lock()
        let isBlurred = blurred[id]
        blurredLock.unlock()
        print("🔍 [MediaCleanerCacheService] getBlurred(\(id)) -> \(isBlurred?.description ?? "nil")")
        return isBlurred
    }

    func getDuplicate(id: String) -> (Bool, Double)? {
        duplicateLock.lock()
        let tuple = duplicates[id]
        duplicateLock.unlock()
        print("🔍 [MediaCleanerCacheService] getDuplicate(\(id)) -> \(tuple?.0.description ?? "nil"), \(tuple?.1.description ?? "nil")")
        return tuple
    }

    func getSize(id: String) -> Double? {
        sizeLock.lock()
        let size = sizes[id]
        sizeLock.unlock()
        print("🔍 [MediaCleanerCacheService] getSize(\(id)) -> \(size?.description ?? "nil")")
        return size
    }
    
    func getSwipeDecision(id: String) -> Bool? {
        let swipeId = "swipe_\(id)"
        blurredLock.lock()
        let decision = blurred[swipeId]
        blurredLock.unlock()
        print("SWIPE:DB:TEST - getSwipeDecision for id=\(id) -> swipeId=\(swipeId) -> result=\(decision?.description ?? "nil")")
        return decision
    }
    
    func getTotalSwipeDecisionsForDeletion() -> Int {
        print("UPDATE:COUNT:TEST - getTotalSwipeDecisionsForDeletion() called")
        blurredLock.lock()
        
        // Подсчитаем все swipe decisions для отладки
        let allSwipeDecisions = blurred.filter { $0.key.hasPrefix("swipe_") }
        print("UPDATE:COUNT:TEST - Total swipe decisions in cache: \(allSwipeDecisions.count)")
        
        for (key, value) in allSwipeDecisions {
            let cleanKey = String(key.dropFirst("swipe_".count))
            print("UPDATE:COUNT:TEST - Swipe decision: \(cleanKey) = \(value) (\(value ? "keep" : "delete"))")
        }
        
        let count = blurred.compactMap { (key, value) -> Bool? in
            // Ищем только swipe decisions (ключи начинаются с "swipe_")
            guard key.hasPrefix("swipe_") else { return nil }
            // Возвращаем true только если decision = false (marked for deletion)
            return value == false ? true : nil
        }.count
        blurredLock.unlock()
        
        print("SWIPE:TOTAL:COUNT - getTotalSwipeDecisionsForDeletion() -> \(count)")
        print("UPDATE:COUNT:TEST - Final count for deletion: \(count)")
        return count
    }

    // MARK: Set

    func setBlurred(id: String, value: Bool) {
        print("💾 [MediaCleanerCacheService] setBlurred(\(id), \(value)) - checking if update needed")
        blurredLock.lock()
        let existingValue = blurred[id]
        
        // Only update if value actually changed
        if existingValue != value {
            blurred[id] = value
            print("   ✏️ [MediaCleanerCacheService] Value changed from \(existingValue?.description ?? "nil") to \(value), sending signal")
            print("   📤 [MediaCleanerCacheService] Sending signal to saveBlurredSubject")
            saveBlurredSubject.send(())
            print("   ✅ [MediaCleanerCacheService] Blurred cache updated, total items: \(blurred.count)")
        } else {
            print("   ⚠️ [MediaCleanerCacheService] Value unchanged (\(value)), skipping update")
        }
        blurredLock.unlock()
    }

    func setDuplicate(id: String, value: Bool, equality: Double) {
        print("💾 [MediaCleanerCacheService] setDuplicate(\(id), \(value), \(equality)) - checking if update needed")
        duplicateLock.lock()
        let existingTuple = duplicates[id]
        let newTuple = (value, equality)
        
        // Only update if value actually changed
        if existingTuple?.0 != newTuple.0 || existingTuple?.1 != newTuple.1 {
            duplicates[id] = newTuple
            print("   ✏️ [MediaCleanerCacheService] Value changed from (\(existingTuple?.0.description ?? "nil"), \(existingTuple?.1.description ?? "nil")) to (\(value), \(equality)), sending signal")
            print("   📤 [MediaCleanerCacheService] Sending signal to saveDuplicatesSubject")
            saveDuplicatesSubject.send(())
            print("   ✅ [MediaCleanerCacheService] Duplicates cache updated, total items: \(duplicates.count)")
        } else {
            print("   ⚠️ [MediaCleanerCacheService] Value unchanged (\(value), \(equality)), skipping update")
        }
        duplicateLock.unlock()
    }

    func setSize(id: String, value: Double) {
        print("💾 [MediaCleanerCacheService] setSize(\(id), \(value)) - checking if update needed")
        sizeLock.lock()
        let existingValue = sizes[id]
        
        // Only update if value actually changed
        if existingValue != value {
            sizes[id] = value
            print("   ✏️ [MediaCleanerCacheService] Value changed from \(existingValue?.description ?? "nil") to \(value), sending signal")
            print("   📤 [MediaCleanerCacheService] Sending signal to saveSizesSubject")
            saveSizesSubject.send(())
            print("   ✅ [MediaCleanerCacheService] Sizes cache updated, total items: \(sizes.count)")
        } else {
            print("   ⚠️ [MediaCleanerCacheService] Value unchanged (\(value)), skipping update")
        }
        sizeLock.unlock()
    }
    
    func setSwipeDecision(id: String, ignored: Bool) {
        let swipeId = "swipe_\(id)"
        print("SWIPE:DB:TEST - setSwipeDecision for id=\(id) -> swipeId=\(swipeId), ignored=\(ignored)")
        
        blurredLock.lock()
        let existingValue = blurred[swipeId]
        
        // Only update if value actually changed
        if existingValue != ignored {
            blurred[swipeId] = ignored
            blurredLock.unlock()
            print("SWIPE:DB:TEST - Value changed, saving to Core Data")
            
            // Save immediately (no throttling for swipe decisions)
            saveSwipeDecisionImmediately(id: swipeId, ignored: ignored)
        } else {
            print("SWIPE:DB:TEST - Value unchanged (\(ignored)), skipping")
            blurredLock.unlock()
        }
    }

    // MARK: Delete

    func deleteBlurred(id: String) {
        storagePerformer.get(MediaCacheBlurredEntity.self, id: id) { [weak self] object in
            guard let self = self, let object = object else { return }
            
            self.storagePerformer.delete(object) { [weak self] error in
                guard let self = self else { return }
                
                if error == nil {
                    self.deleteSize(id: id)
                    self.blurredLock.lock()
                    self.blurred[id] = nil
                    self.blurredLock.unlock()
                    self.logger.debug("✅ Successfully deleted blurred cache for id: \(id)")
                } else {
                    self.logger.error("❌ Failed to delete blurred cache for id: \(id), error: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    func deleteSize(id: String) {
        storagePerformer.get(MediaCacheSizeEntity.self, id: id) { [weak self] object in
            guard let self = self, let object = object else { return }
            
            self.storagePerformer.delete(object) { [weak self] error in
                guard let self = self else { return }
                
                if error == nil {
                    self.sizeLock.lock()
                    self.sizes[id] = nil
                    self.sizeLock.unlock()
                    self.logger.debug("✅ Successfully deleted size cache for id: \(id)")
                } else {
                    self.logger.error("❌ Failed to delete size cache for id: \(id), error: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    func deleteDuplicate(id: String) {
        storagePerformer.get(MediaCacheDuplicateEntity.self, id: id) { [weak self] object in
            guard let self = self, let object = object else { return }
            
            self.storagePerformer.delete(object) { [weak self] error in
                guard let self = self else { return }
                
                if error == nil {
                    self.deleteSize(id: id)
                    self.duplicateLock.lock()
                    self.duplicates[id] = nil
                    self.duplicateLock.unlock()
                    self.logger.debug("✅ Successfully deleted duplicate cache for id: \(id)")
                } else {
                    self.logger.error("❌ Failed to delete duplicate cache for id: \(id), error: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    func deleteSwipeDecision(id: String) {
        let swipeId = "swipe_\(id)"
        
        storagePerformer.get(MediaCacheBlurredEntity.self, id: swipeId) { [weak self] object in
            guard let self = self, let object = object else { return }
            
            self.storagePerformer.delete(object) { [weak self] error in
                guard let self = self else { return }
                
                if error == nil {
                    self.blurredLock.lock()
                    self.blurred[swipeId] = nil
                    self.blurredLock.unlock()
                } else {
                    print("SWIPE:DB:TEST - Failed to delete swipe decision: \(swipeId), error: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    func deleteAllDuplicates() {
        storagePerformer.deleteObjects(of: MediaCacheDuplicateEntity.self) { [weak self] error in
            guard let self = self else { return }
            
            if error == nil {
                self.duplicateLock.lock()
                self.duplicates = [:]
                self.duplicateLock.unlock()
                self.logger.info("✅ Successfully deleted all duplicate caches")
            } else {
                self.logger.error("❌ Failed to delete all duplicate caches, error: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    // MARK: Save

    private func saveBlurred() {
        print("🔵 [MediaCleanerCacheService] saveBlurred() started")
        
        // Check if already saving
        if isSavingBlurred {
            print("   ⚠️ [MediaCleanerCacheService] saveBlurred already in progress, skipping")
            return
        }
        
        isSavingBlurred = true
        blurredLock.lock()
        let blurredCopy = blurred
        blurredLock.unlock()
        
        print("   📊 [MediaCleanerCacheService] Current blurred cache size: \(blurredCopy.count)")
        guard !blurredCopy.isEmpty else { 
            print("   ⚠️ [MediaCleanerCacheService] Blurred cache is empty, skipping save")
            isSavingBlurred = false
            return 
        }
        
        print("   🔍 [MediaCleanerCacheService] Fetching existing blurred entities from Core Data")
        storagePerformer.get(MediaCacheBlurredEntity.self) { [weak self] result in
            guard let self = self else { 
                print("   ❌ [MediaCleanerCacheService] saveBlurred - no self")
                return 
            }
            
            // Reset flag when operation completes
            defer { self.isSavingBlurred = false }
            
            let existingIds = Set(result?.compactMap { $0.id } ?? [])
            let toWrite = blurredCopy.filter { !existingIds.contains($0.key) }
            
            print("   📋 [MediaCleanerCacheService] Existing in DB: \(existingIds.count), New to write: \(toWrite.count)")
            guard !toWrite.isEmpty else { 
                print("   ℹ️ [MediaCleanerCacheService] Nothing new to save for blurred cache")
                return 
            }
            
            let cacheData = toWrite.map { (id, value) in
                MediaCacheBlurredData(id: id, value: value)
            }
            
            print("   📤 [MediaCleanerCacheService] Calling StoragePerformer.addBlurredCache() with \(cacheData.count) items")
            self.storagePerformer.addBlurredCache(cacheData) { [weak self] error in
                if let error = error {
                    print("   ❌ [MediaCleanerCacheService] Failed to save blurred cache: \(error)")
                    self?.logger.error("❌ Failed to save blurred cache: \(error.localizedDescription)")
                } else {
                    print("   ✅ [MediaCleanerCacheService] Successfully saved \(cacheData.count) blurred cache items")
                    self?.logger.debug("✅ Successfully saved \(cacheData.count) blurred cache items")
                }
            }
        }
    }

    private func saveDuplicates() {
        print("🟡 [MediaCleanerCacheService] saveDuplicates() started")
        
        // Check if already saving
        if isSavingDuplicates {
            print("   ⚠️ [MediaCleanerCacheService] saveDuplicates already in progress, skipping")
            return
        }
        
        isSavingDuplicates = true
        duplicateLock.lock()
        let duplicateCopy = duplicates
        duplicateLock.unlock()
        
        print("   📊 [MediaCleanerCacheService] Current duplicates cache size: \(duplicateCopy.count)")
        guard !duplicateCopy.isEmpty else { 
            print("   ⚠️ [MediaCleanerCacheService] Duplicates cache is empty, skipping save")
            isSavingDuplicates = false
            return 
        }
        
        print("   🔍 [MediaCleanerCacheService] Fetching existing duplicate entities from Core Data")
        storagePerformer.get(MediaCacheDuplicateEntity.self) { [weak self] result in
            guard let self = self else { 
                print("   ❌ [MediaCleanerCacheService] saveDuplicates - no self")
                return 
            }
            
            // Reset flag when operation completes
            defer { self.isSavingDuplicates = false }
            
            let existingIds = Set(result?.compactMap { $0.id } ?? [])
            let toWrite = duplicateCopy.filter { !existingIds.contains($0.key) }
            
            print("   📋 [MediaCleanerCacheService] Existing in DB: \(existingIds.count), New to write: \(toWrite.count)")
            guard !toWrite.isEmpty else { 
                print("   ℹ️ [MediaCleanerCacheService] Nothing new to save for duplicates cache")
                return 
            }
            
            let cacheData = toWrite.map { (id, tuple) in
                MediaCacheDuplicateData(id: id, value: tuple.0, equality: tuple.1)
            }
            
            print("   📤 [MediaCleanerCacheService] Calling StoragePerformer.addDuplicateCache() with \(cacheData.count) items")
            self.storagePerformer.addDuplicateCache(cacheData) { [weak self] error in
                if let error = error {
                    print("   ❌ [MediaCleanerCacheService] Failed to save duplicate cache: \(error)")
                    self?.logger.error("❌ Failed to save duplicate cache: \(error.localizedDescription)")
                } else {
                    print("   ✅ [MediaCleanerCacheService] Successfully saved \(cacheData.count) duplicate cache items")
                    self?.logger.debug("✅ Successfully saved \(cacheData.count) duplicate cache items")
                }
            }
        }
    }

    private func saveSizes() {
        print("🟢 [MediaCleanerCacheService] saveSizes() started")
        
        // Check if already saving
        if isSavingSizes {
            print("   ⚠️ [MediaCleanerCacheService] saveSizes already in progress, skipping")
            return
        }
        
        isSavingSizes = true
        sizeLock.lock()
        let sizesCopy = sizes
        sizeLock.unlock()
        
        print("   📊 [MediaCleanerCacheService] Current sizes cache size: \(sizesCopy.count)")
        guard !sizesCopy.isEmpty else { 
            print("   ⚠️ [MediaCleanerCacheService] Sizes cache is empty, skipping save")
            isSavingSizes = false
            return 
        }
        
        print("   🔍 [MediaCleanerCacheService] Fetching existing size entities from Core Data")
        storagePerformer.get(MediaCacheSizeEntity.self) { [weak self] result in
            guard let self = self else { 
                print("   ❌ [MediaCleanerCacheService] saveSizes - no self")
                return 
            }
            
            // Reset flag when operation completes
            defer { self.isSavingSizes = false }
            
            let existingIds = Set(result?.compactMap { $0.id } ?? [])
            let toWrite = sizesCopy.filter { !existingIds.contains($0.key) }
            
            print("   📋 [MediaCleanerCacheService] Existing in DB: \(existingIds.count), New to write: \(toWrite.count)")
            guard !toWrite.isEmpty else { 
                print("   ℹ️ [MediaCleanerCacheService] Nothing new to save for sizes cache")
                return 
            }
            
            let cacheData = toWrite.map { (id, value) in
                MediaCacheSizeData(id: id, value: value)
            }
            
            print("   📤 [MediaCleanerCacheService] Calling StoragePerformer.addSizeCache() with \(cacheData.count) items")
            self.storagePerformer.addSizeCache(cacheData) { [weak self] error in
                if let error = error {
                    print("   ❌ [MediaCleanerCacheService] Failed to save size cache: \(error)")
                    self?.logger.error("❌ Failed to save size cache: \(error.localizedDescription)")
                } else {
                    print("   ✅ [MediaCleanerCacheService] Successfully saved \(cacheData.count) size cache items")
                    self?.logger.debug("✅ Successfully saved \(cacheData.count) size cache items")
                }
            }
        }
    }
    
    private func saveSwipeDecisionImmediately(id: String, ignored: Bool) {
        print("SWIPE:DB:TEST - saveSwipeDecisionImmediately called with id=\(id), ignored=\(ignored)")
        
        // Check if this swipe decision already exists in Core Data
        storagePerformer.get(MediaCacheBlurredEntity.self, id: id) { [weak self] existingObject in
            guard let self = self else { return }
            
            if let existingObject = existingObject {
                print("SWIPE:DB:TEST - Found existing swipe decision in Core Data for id=\(id)")
                // Update existing entry
                // Note: StoragePerformer doesn't seem to have update method, so we delete and recreate
                self.storagePerformer.delete(existingObject) { [weak self] error in
                    if let error = error {
                        print("SWIPE:DB:TEST - Failed to delete existing swipe decision for update: \(error)")
                        return
                    }
                    print("SWIPE:DB:TEST - Deleted existing entry, creating new one")
                    
                    // CRITICAL FIX: Remove from in-memory cache after deletion
                    self?.blurredLock.lock()
                    self?.blurred[id] = nil
                    self?.blurredLock.unlock()
                    
                    // Create new entry after deletion
                    self?.createNewSwipeDecision(id: id, ignored: ignored)
                }
            } else {
                print("SWIPE:DB:TEST - No existing swipe decision found, creating new one for id=\(id)")
                // Create new entry
                self.createNewSwipeDecision(id: id, ignored: ignored)
            }
        }
    }
    
    private func createNewSwipeDecision(id: String, ignored: Bool) {
        print("SWIPE:DB:TEST - createNewSwipeDecision called with id=\(id), ignored=\(ignored)")
        let cacheData = [MediaCacheBlurredData(id: id, value: ignored)]
        
        storagePerformer.addBlurredCache(cacheData) { [weak self] error in
            if let error = error {
                print("SWIPE:DB:TEST - Failed to save swipe decision to DB: \(error)")
            } else {
                print("SWIPE:DB:TEST - Successfully saved swipe decision to Core Data: id=\(id), ignored=\(ignored)")
                
                // CRITICAL FIX: Update in-memory cache after successful Core Data save
                self?.blurredLock.lock()
                self?.blurred[id] = ignored
                self?.blurredLock.unlock()
                print("SWIPE:DB:TEST - Updated in-memory cache for id=\(id), ignored=\(ignored)")
            }
        }
    }

    // MARK: Prepare

    private func prepareBlurred() {
        print("SWIPE:DB:TEST - prepareBlurred() called - loading from Core Data")
        storagePerformer.get(MediaCacheBlurredEntity.self) { [weak self] result in
            guard let self = self else { 
                print("SWIPE:DB:TEST - prepareBlurred - no self")
                return 
            }
            
            guard let entities = result else { 
                print("SWIPE:DB:TEST - No blurred entities found in Core Data")
                return 
            }
            
            print("SWIPE:DB:TEST - Found \(entities.count) blurred entities in Core Data")
            
            var objectsToDelete: [MediaCacheBlurredEntity] = []
            var objectsToLeave: [MediaCacheBlurredEntity] = []
            var swipeDecisionCount = 0
            
            let oneMonthAgo = Date().timeIntervalSince1970 - TimeInterval.month
            
            for entity in entities {
                if entity.date?.timeIntervalSince1970 ?? 0 < oneMonthAgo {
                    objectsToDelete.append(entity)
                } else {
                    objectsToLeave.append(entity)
                    if entity.id?.hasPrefix("swipe_") == true {
                        swipeDecisionCount += 1
                        print("SWIPE:DB:TEST - Found swipe decision in Core Data: \(entity.id ?? "nil") = \(entity.value)")
                    }
                }
            }
            
            print("SWIPE:DB:TEST - Blurred entities to delete (>1 month): \(objectsToDelete.count)")
            print("SWIPE:DB:TEST - Blurred entities to keep: \(objectsToLeave.count), swipe decisions: \(swipeDecisionCount)")
            
            if !objectsToDelete.isEmpty {
                self.storagePerformer.delete(objects: objectsToDelete) { [weak self] error in
                    if let error = error {
                        print("SWIPE:DB:TEST - Failed to delete old blurred cache entries: \(error)")
                        self?.logger.error("❌ Failed to delete old blurred cache entries: \(error.localizedDescription)")
                    } else {
                        print("SWIPE:DB:TEST - Deleted \(objectsToDelete.count) old blurred cache entries")
                        self?.logger.debug("✅ Deleted \(objectsToDelete.count) old blurred cache entries")
                    }
                }
            }
            
            self.blurredLock.lock()
            for entity in objectsToLeave {
                if let id = entity.id {
                    self.blurred[id] = entity.value
                    if id.hasPrefix("swipe_") {
                        print("SWIPE:DB:TEST - Added to in-memory cache: \(id) = \(entity.value)")
                    }
                }
            }
            self.blurredLock.unlock()
            
            print("SWIPE:DB:TEST - Prepared blurred cache with \(objectsToLeave.count) entries, \(swipeDecisionCount) swipe decisions")
            self.logger.debug("📖 Prepared blurred cache with \(objectsToLeave.count) entries")
        }
    }

    private func prepareDuplicates() {
        print("🟡 [MediaCleanerCacheService] prepareDuplicates() - loading from Core Data")
        storagePerformer.get(MediaCacheDuplicateEntity.self) { [weak self] result in
            guard let self = self else { 
                print("   ❌ [MediaCleanerCacheService] prepareDuplicates - no self")
                return 
            }
            
            guard let entities = result else { 
                print("   ℹ️ [MediaCleanerCacheService] No duplicate entities found in Core Data")
                return 
            }
            
            print("   📊 [MediaCleanerCacheService] Found \(entities.count) duplicate entities in Core Data")
            
            self.duplicateLock.lock()
            for entity in entities {
                if let id = entity.id {
                    self.duplicates[id] = (entity.value, entity.equality)
                }
            }
            self.duplicateLock.unlock()
            
            print("   ✅ [MediaCleanerCacheService] Prepared duplicate cache with \(entities.count) entries")
            self.logger.debug("📖 Prepared duplicate cache with \(entities.count) entries")
        }
    }

    private func prepareSizes() {
        print("🟢 [MediaCleanerCacheService] prepareSizes() - loading from Core Data")
        storagePerformer.get(MediaCacheSizeEntity.self) { [weak self] result in
            guard let self = self else { 
                print("   ❌ [MediaCleanerCacheService] prepareSizes - no self")
                return 
            }
            
            guard let entities = result else { 
                print("   ℹ️ [MediaCleanerCacheService] No size entities found in Core Data")
                return 
            }
            
            print("   📊 [MediaCleanerCacheService] Found \(entities.count) size entities in Core Data")
            
            var objectsToDelete: [MediaCacheSizeEntity] = []
            var objectsToLeave: [MediaCacheSizeEntity] = []
            
            let oneMonthAgo = Date().timeIntervalSince1970 - TimeInterval.month
            
            for entity in entities {
                if entity.date?.timeIntervalSince1970 ?? 0 < oneMonthAgo {
                    objectsToDelete.append(entity)
                } else {
                    objectsToLeave.append(entity)
                }
            }
            
            print("   🗑️ [MediaCleanerCacheService] Size entities to delete (>1 month): \(objectsToDelete.count)")
            print("   ✅ [MediaCleanerCacheService] Size entities to keep: \(objectsToLeave.count)")
            
            if !objectsToDelete.isEmpty {
                self.storagePerformer.delete(objects: objectsToDelete) { [weak self] error in
                    if let error = error {
                        print("   ❌ [MediaCleanerCacheService] Failed to delete old size cache entries: \(error)")
                        self?.logger.error("❌ Failed to delete old size cache entries: \(error.localizedDescription)")
                    } else {
                        print("   ✅ [MediaCleanerCacheService] Deleted \(objectsToDelete.count) old size cache entries")
                        self?.logger.debug("✅ Deleted \(objectsToDelete.count) old size cache entries")
                    }
                }
            }
            
            self.sizeLock.lock()
            for entity in objectsToLeave {
                if let id = entity.id {
                    self.sizes[id] = entity.value
                }
            }
            self.sizeLock.unlock()
            
            print("   ✅ [MediaCleanerCacheService] Prepared size cache with \(objectsToLeave.count) entries")
            self.logger.debug("📖 Prepared size cache with \(objectsToLeave.count) entries")
        }
    }

    private func cleanAllBlurred() {
        print("🧹 [MediaCleanerCacheService] cleanAllBlurred() - clearing all blurred cache")
        storagePerformer.deleteObjects(of: MediaCacheBlurredEntity.self) { [weak self] error in
            guard let self = self else { 
                print("   ❌ [MediaCleanerCacheService] cleanAllBlurred - no self")
                return 
            }
            
            if error == nil {
                self.blurredLock.lock()
                let previousCount = self.blurred.count
                self.blurred = [:]
                self.blurredLock.unlock()
                print("   ✅ [MediaCleanerCacheService] Successfully cleaned all blurred cache (cleared \(previousCount) items)")
                self.logger.info("✅ Successfully cleaned all blurred cache")
            } else {
                print("   ❌ [MediaCleanerCacheService] Failed to clean all blurred cache: \(error?.localizedDescription ?? "unknown")")
                self.logger.error("❌ Failed to clean all blurred cache: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
}

// MARK: - Extensions

extension TimeInterval {
    static let month: TimeInterval = 30 * 24 * 60 * 60 // 30 days in seconds
}

// MARK: - Debug Prints Added
// 📱 Инициализация сервисов
// 🔍 Get операции (чтение из кеша)  
// 💾 Set операции (запись в кеш + сигналы)
// 🔵🟡🟢 Save операции (throttled сохранение в Core Data)
// 📤 StoragePerformer операции (CRUD в Core Data)
// 🔧 Core Data контексты
// 🧹 Очистка кеша
// ⚙️ Combine pipelines


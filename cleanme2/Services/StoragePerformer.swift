import CoreData
import os.log

// MARK: - Data Transfer Objects
struct MediaCacheBlurredData {
    let id: String
    let value: Bool
    let date: Date
    
    init(id: String, value: Bool, date: Date = Date()) {
        self.id = id
        self.value = value
        self.date = date
    }
}

struct MediaCacheDuplicateData {
    let id: String
    let value: Bool
    let equality: Double
    let date: Date
    
    init(id: String, value: Bool, equality: Double, date: Date = Date()) {
        self.id = id
        self.value = value
        self.equality = equality
        self.date = date
    }
}

struct MediaCacheSizeData {
    let id: String
    let value: Double
    let date: Date
    
    init(id: String, value: Double, date: Date = Date()) {
        self.id = id
        self.value = value
        self.date = date
    }
}

protocol StoragePerformer {
    func addBlurredCache(_ data: [MediaCacheBlurredData], completion: @escaping (Error?) -> Void)
    func addDuplicateCache(_ data: [MediaCacheDuplicateData], completion: @escaping (Error?) -> Void)
    func addSizeCache(_ data: [MediaCacheSizeData], completion: @escaping (Error?) -> Void)
    
    func delete<Element: NSManagedObject>(_ object: Element, completion: @escaping (Error?) -> Void)
    func delete<Element: NSManagedObject>(objects: [Element], completion: @escaping (Error?) -> Void)
    func deleteObjects<Element: NSManagedObject>(of type: Element.Type, completion: @escaping (Error?) -> Void)
    
    func get<Element: NSManagedObject>(_ type: Element.Type, completion: @escaping ([Element]?) -> Void)
    func get<Element: NSManagedObject>(_ type: Element.Type, id: String, completion: @escaping (Element?) -> Void)
}

final class StoragePerformerImpl: StoragePerformer {
    enum CustomError: Error {
        case noContext
        case entityNotFound
    }

    private let logger = Logger(subsystem: "com.kirillmaximchik.cleanme2", category: "StoragePerformer")
    private let queue = DispatchQueue(label: "StoragePerformerQueue", qos: .userInitiated)
    private let persistentContainer: NSPersistentContainer

    init(persistentContainer: NSPersistentContainer = PersistenceController.shared.container) {
        self.persistentContainer = persistentContainer
        logger.info("🏗️ StoragePerformer initialized with Core Data")
        print("📱 [StoragePerformer] Initialized with container: \(persistentContainer)")
    }

    func addBlurredCache(_ data: [MediaCacheBlurredData], completion: @escaping (Error?) -> Void) {
        print("🔵 [StoragePerformer] addBlurredCache called with \(data.count) items")
        print("   📋 Items: \(data.map { "\($0.id): \($0.value)" }.joined(separator: ", "))")
        
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [StoragePerformer] addBlurredCache - no self")
                completion(CustomError.noContext)
                return
            }
            
            print("🔧 [StoragePerformer] Creating new background context for blurred cache")
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    print("💾 [StoragePerformer] Starting to save \(data.count) blurred entities")
                    for (index, item) in data.enumerated() {
                        let entity = MediaCacheBlurredEntity(context: context)
                        entity.id = item.id
                        entity.value = item.value
                        entity.date = item.date
                        print("   \(index + 1). Created entity for ID: \(item.id), value: \(item.value)")
                    }
                    
                    try context.save()
                    print("✅ [StoragePerformer] Successfully saved \(data.count) blurred cache objects to Core Data")
                    self.logger.debug("✅ Successfully saved \(data.count) blurred cache objects")
                    completion(nil)
                } catch {
                    print("❌ [StoragePerformer] Core Data blurred cache writing error: \(error)")
                    self.logger.error("❌ Core Data blurred cache writing error: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }
    
    func addDuplicateCache(_ data: [MediaCacheDuplicateData], completion: @escaping (Error?) -> Void) {
        print("🟡 [StoragePerformer] addDuplicateCache called with \(data.count) items")
        print("   📋 Items: \(data.map { "\($0.id): \($0.value), equality: \($0.equality)" }.joined(separator: ", "))")
        
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [StoragePerformer] addDuplicateCache - no self")
                completion(CustomError.noContext)
                return
            }
            
            print("🔧 [StoragePerformer] Creating new background context for duplicate cache")
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    print("💾 [StoragePerformer] Starting to save \(data.count) duplicate entities")
                    for (index, item) in data.enumerated() {
                        let entity = MediaCacheDuplicateEntity(context: context)
                        entity.id = item.id
                        entity.value = item.value
                        entity.equality = item.equality
                        entity.date = item.date
                        print("   \(index + 1). Created entity for ID: \(item.id), value: \(item.value), equality: \(item.equality)")
                    }
                    
                    try context.save()
                    print("✅ [StoragePerformer] Successfully saved \(data.count) duplicate cache objects to Core Data")
                    self.logger.debug("✅ Successfully saved \(data.count) duplicate cache objects")
                    completion(nil)
                } catch {
                    print("❌ [StoragePerformer] Core Data duplicate cache writing error: \(error)")
                    self.logger.error("❌ Core Data duplicate cache writing error: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }
    
    func addSizeCache(_ data: [MediaCacheSizeData], completion: @escaping (Error?) -> Void) {
        print("🟢 [StoragePerformer] addSizeCache called with \(data.count) items")
        print("   📋 Items: \(data.map { "\($0.id): \($0.value)" }.joined(separator: ", "))")
        
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [StoragePerformer] addSizeCache - no self")
                completion(CustomError.noContext)
                return
            }
            
            print("🔧 [StoragePerformer] Creating new background context for size cache")
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    print("💾 [StoragePerformer] Starting to save \(data.count) size entities")
                    for (index, item) in data.enumerated() {
                        let entity = MediaCacheSizeEntity(context: context)
                        entity.id = item.id
                        entity.value = item.value
                        entity.date = item.date
                        print("   \(index + 1). Created entity for ID: \(item.id), value: \(item.value)")
                    }
                    
                    try context.save()
                    print("✅ [StoragePerformer] Successfully saved \(data.count) size cache objects to Core Data")
                    self.logger.debug("✅ Successfully saved \(data.count) size cache objects")
                    completion(nil)
                } catch {
                    print("❌ [StoragePerformer] Core Data size cache writing error: \(error)")
                    self.logger.error("❌ Core Data size cache writing error: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }

    func delete<Element: NSManagedObject>(_ object: Element, completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    // Get the object in this context using its objectID
                    let objectInContext = try context.existingObject(with: object.objectID)
                    context.delete(objectInContext)
                    
                    try context.save()
                    self.logger.debug("✅ Successfully deleted object")
                    completion(nil)
                } catch {
                    self.logger.error("❌ Core Data deletion error: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }

    func delete<Element: NSManagedObject>(objects: [Element], completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    // Get objects in this context and delete them
                    for object in objects {
                        let objectInContext = try context.existingObject(with: object.objectID)
                        context.delete(objectInContext)
                    }
                    
                    try context.save()
                    self.logger.debug("✅ Successfully deleted \(objects.count) objects")
                    completion(nil)
                } catch {
                    self.logger.error("❌ Core Data multiple deletion error: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }

    func deleteObjects<Element: NSManagedObject>(of type: Element.Type, completion: @escaping (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(CustomError.noContext)
                return
            }
            
            let context = self.persistentContainer.newBackgroundContext()
            context.perform {
                do {
                    let entityName = String(describing: type)
                    let fetchRequest = NSFetchRequest<Element>(entityName: entityName)
                    let objects = try context.fetch(fetchRequest)
                    
                    for object in objects {
                        context.delete(object)
                    }
                    
                    try context.save()
                    self.logger.debug("✅ Successfully deleted all objects of type \(entityName)")
                    completion(nil)
                } catch {
                    self.logger.error("❌ Core Data type deletion error: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }

    func get<Element: NSManagedObject>(_ type: Element.Type, completion: @escaping ([Element]?) -> Void) {
        let entityName = String(describing: type)
        print("🔍 [StoragePerformer] get() called for entity type: \(entityName)")
        
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [StoragePerformer] get(\(entityName)) - no self")
                completion(nil)
                return
            }
            
            print("🔧 [StoragePerformer] Using view context for fetching \(entityName)")
            let context = self.persistentContainer.viewContext
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<Element>(entityName: entityName)
                    let objects = try context.fetch(fetchRequest)
                    print("✅ [StoragePerformer] Successfully fetched \(objects.count) objects of type \(entityName)")
                    completion(objects)
                } catch {
                    print("❌ [StoragePerformer] Core Data fetch error for \(entityName): \(error)")
                    self.logger.error("❌ Core Data fetch error: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }

    func get<Element: NSManagedObject>(_ type: Element.Type, id: String, completion: @escaping (Element?) -> Void) {
        let entityName = String(describing: type)
        print("🔍 [StoragePerformer] get(by id) called for entity type: \(entityName), id: \(id)")
        
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [StoragePerformer] get(\(entityName), id: \(id)) - no self")
                completion(nil)
                return
            }
            
            print("🔧 [StoragePerformer] Using view context for fetching \(entityName) by id")
            let context = self.persistentContainer.viewContext
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<Element>(entityName: entityName)
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id)
                    fetchRequest.fetchLimit = 1
                    
                    let objects = try context.fetch(fetchRequest)
                    if objects.first != nil {
                        print("✅ [StoragePerformer] Found object of type \(entityName) with id: \(id)")
                    } else {
                        print("🔍 [StoragePerformer] No object found of type \(entityName) with id: \(id)")
                    }
                    completion(objects.first)
                } catch {
                    print("❌ [StoragePerformer] Core Data fetch by id error for \(entityName): \(error)")
                    self.logger.error("❌ Core Data fetch by id error: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
}


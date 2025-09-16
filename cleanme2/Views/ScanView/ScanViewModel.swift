import SwiftUI
import Combine
import Contacts

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var subtitle = ""
    @Published var progress = Double.zero

    @Published var previews = MediaCleanerServicePreviews(
        _similar: nil,
        _duplicates: nil,
        _blurred: nil,
        _screenshots: nil,
        _videos: nil
    )
    @Published var counts = MediaCleanerServiceCounts<Int>()
    @Published var megabytes = MediaCleanerServiceCounts<Double>()
    
    // Добавляем поддержку контактов и календаря
    @Published var contactsCount: Int = 0
    @Published var calendarEventsCount: Int = 0
    @Published var isContactsLoading: Bool = false
    @Published var isCalendarLoading: Bool = false
    
    // Состояния разрешений
    @Published var contactsPermissionStatus: ContactPermissionStatus = .notDetermined
    @Published var calendarPermissionStatus: CalendarPermissionStatus = .notDetermined
    
    enum ContactPermissionStatus {
        case notDetermined
        case denied
        case authorized
        case loading
    }
    
    enum CalendarPermissionStatus {
        case notDetermined
        case denied
        case authorized
        case loading
    }

    private let mediaCleanerService: MediaCleanerService = {
        print("SCAN:TEST - ScanViewModel accessing MediaCleanerServiceImpl.shared")
        let service = MediaCleanerServiceImpl.shared
        print("SCAN:TEST - ScanViewModel got MediaCleanerServiceImpl.shared")
        return service
    }()
    private let contactsViewModel: ContactsViewModel
    private let calendarService: CalendarService

    private var cancellables = Set<AnyCancellable>()

    private let purchaseService = ApphudPurchaseService()

    var hasActiveSubscription: Bool {
        purchaseService.hasActiveSubscription
    }
    
    init() {
        print("SCAN:TEST - ScanViewModel init started")
        self.contactsViewModel = ContactsViewModel()
        self.calendarService = CalendarService()
        print("SCAN:TEST - About to setupBindings")
        setupBindings()
        print("SCAN:TEST - About to checkInitialPermissions")
        checkInitialPermissions()
        print("SCAN:TEST - ScanViewModel init completed, progress: \(progress)")
    }
    
    private func checkInitialPermissions() {
        // Проверяем разрешения контактов
        let contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
        switch contactsStatus {
        case .authorized, .limited:
            contactsPermissionStatus = .authorized
        case .denied, .restricted:
            contactsPermissionStatus = .denied
        case .notDetermined:
            contactsPermissionStatus = .notDetermined
        @unknown default:
            contactsPermissionStatus = .notDetermined
        }
        
        // Проверяем разрешения календаря
        let calendarStatus = calendarService.authorizationStatus
        if #available(iOS 17.0, *) {
            switch calendarStatus {
            case .fullAccess:
                calendarPermissionStatus = .authorized
            case .denied, .restricted:
                calendarPermissionStatus = .denied
            case .notDetermined:
                calendarPermissionStatus = .notDetermined
            case .writeOnly:
                calendarPermissionStatus = .denied
            @unknown default:
                calendarPermissionStatus = .notDetermined
            }
        } else {
            switch calendarStatus {
            case .authorized, .fullAccess, .writeOnly:
                calendarPermissionStatus = .authorized
            case .denied, .restricted:
                calendarPermissionStatus = .denied
            case .notDetermined:
                calendarPermissionStatus = .notDetermined
            @unknown default:
                calendarPermissionStatus = .notDetermined
            }
        }
    }

    func onAppear() {
        print("SCAN:TEST - onAppear called, current progress: \(progress)")
        // Сначала запрашиваем все разрешения, затем загружаем данные
        requestAllPermissions()
    }
    
    /// Запрашивает все необходимые разрешения при запуске приложения
    private func requestAllPermissions() {
        print("SCAN:TEST - Starting permission requests for all services")
        
        Task { @MainActor in
            // Запрашиваем разрешения параллельно
            async let photoPermission = requestPhotoLibraryPermission()
            async let contactsPermission = requestContactsPermissionAsync()
            async let calendarPermission = requestCalendarPermissionAsync()
            
            // Ждем получения всех разрешений
            let (photoGranted, contactsGranted, calendarGranted) = await (photoPermission, contactsPermission, calendarPermission)
            
            print("SCAN:TEST - Permissions received - Photo: \(photoGranted), Contacts: \(contactsGranted), Calendar: \(calendarGranted)")
            
            // Запускаем загрузку данных в зависимости от полученных разрешений
            startDataLoading(photoGranted: photoGranted, contactsGranted: contactsGranted, calendarGranted: calendarGranted)
        }
    }
    
    /// Запрашивает разрешение на доступ к фотогалерее
    private func requestPhotoLibraryPermission() async -> Bool {
        print("SCAN:TEST - Requesting photo library permission")
        return await withCheckedContinuation { continuation in
            mediaCleanerService.requestAuthorization { status in
                let granted = status == .authorized || status == .limited
                print("SCAN:TEST - Photo library permission: \(granted)")
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Запрашивает разрешение на доступ к контактам (async версия)
    private func requestContactsPermissionAsync() async -> Bool {
        print("SCAN:TEST - Requesting contacts permission")
        return await withCheckedContinuation { continuation in
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        print("SCAN:TEST - Contacts permission granted")
                        self.contactsPermissionStatus = .authorized
                    } else {
                        print("SCAN:TEST - Contacts permission denied: \(error?.localizedDescription ?? "Unknown error")")
                        self.contactsPermissionStatus = .denied
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Запрашивает разрешение на доступ к календарю (async версия)
    private func requestCalendarPermissionAsync() async -> Bool {
        print("SCAN:TEST - Requesting calendar permission")
        return await withCheckedContinuation { continuation in
            Task {
                await self.calendarService.requestCalendarAccess()
                await MainActor.run {
                    let newStatus = self.calendarService.authorizationStatus
                    var granted = false
                    if #available(iOS 17.0, *) {
                        switch newStatus {
                        case .fullAccess:
                            self.calendarPermissionStatus = .authorized
                            granted = true
                            print("SCAN:TEST - Calendar permission granted (fullAccess)")
                        case .denied, .restricted:
                            self.calendarPermissionStatus = .denied
                            granted = false
                            print("SCAN:TEST - Calendar permission denied")
                        case .writeOnly:
                            self.calendarPermissionStatus = .denied
                            granted = false
                            print("SCAN:TEST - Calendar permission writeOnly (treating as denied)")
                        case .notDetermined:
                            self.calendarPermissionStatus = .notDetermined
                            granted = false
                            print("SCAN:TEST - Calendar permission notDetermined")
                        @unknown default:
                            self.calendarPermissionStatus = .notDetermined
                            granted = false
                        }
                    } else {
                        switch newStatus {
                        case .authorized, .fullAccess, .writeOnly:
                            self.calendarPermissionStatus = .authorized
                            granted = true
                            print("SCAN:TEST - Calendar permission granted")
                        case .denied, .restricted:
                            self.calendarPermissionStatus = .denied
                            granted = false
                            print("SCAN:TEST - Calendar permission denied")
                        case .notDetermined:
                            self.calendarPermissionStatus = .notDetermined
                            granted = false
                            print("SCAN:TEST - Calendar permission notDetermined")
                        @unknown default:
                            self.calendarPermissionStatus = .notDetermined
                            granted = false
                        }
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Запускает загрузку данных в зависимости от полученных разрешений
    private func startDataLoading(photoGranted: Bool, contactsGranted: Bool, calendarGranted: Bool) {
        print("SCAN:TEST - Starting data loading with permissions - Photo: \(photoGranted), Contacts: \(contactsGranted), Calendar: \(calendarGranted)")
        
        // Загружаем фото если есть разрешения
        if photoGranted {
            print("SCAN:TEST - Starting photo scanning")
            mediaCleanerService.resetData()
            mediaCleanerService.scanAllImages()
            mediaCleanerService.scanVideos()
        } else {
            print("SCAN:TEST - Photo access denied, skipping photo scan")
        }
        
        // Загружаем контакты если есть разрешения
        if contactsGranted {
            print("SCAN:TEST - Starting contacts scanning")
            scanContacts()
        } else {
            print("SCAN:TEST - Contacts access denied, skipping contacts scan")
        }
        
        // Загружаем календарь если есть разрешения
        if calendarGranted {
            print("SCAN:TEST - Starting calendar scanning")
            scanCalendar()
        } else {
            print("SCAN:TEST - Calendar access denied, skipping calendar scan")
        }
        
        print("SCAN:TEST - Data loading started for all permitted services")
    }
    
    func scanContacts() {
        // Сначала загружаем локальные контакты
        let localContactsCount = contactsViewModel.getContactsCount()
        
        // Затем проверяем системные контакты если есть разрешения
        if contactsPermissionStatus == .authorized {
            isContactsLoading = true
            Task {
                let systemContactsCount = await loadSystemContactsCount()
                contactsCount = localContactsCount + systemContactsCount
                isContactsLoading = false
            }
        } else {
            contactsCount = localContactsCount
        }
    }
    
    private func loadSystemContactsCount() async -> Int {
        let store = CNContactStore()
        let keysToFetch = [CNContactIdentifierKey] as [CNKeyDescriptor]
        
        return await Task.detached {
            do {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var count = 0
                try store.enumerateContacts(with: request) { _, _ in
                    count += 1
                }
                return count
            } catch {
                print("Error loading system contacts: \(error)")
                return 0
            }
        }.value
    }
    
    func scanCalendar() {
        if calendarPermissionStatus == .authorized {
            isCalendarLoading = true
            Task {
                await calendarService.loadEvents()
                calendarEventsCount = calendarService.events.count
                isCalendarLoading = false
            }
        } else {
            calendarEventsCount = 0
        }
    }
    
    // Методы для запроса разрешений
    func requestContactsPermission() {
        contactsPermissionStatus = .loading
        
        let store = CNContactStore()
        Task {
            do {
                _ = try await store.requestAccess(for: .contacts)
                let newStatus = CNContactStore.authorizationStatus(for: .contacts)
                
                switch newStatus {
                case .authorized:
                    contactsPermissionStatus = .authorized
                    scanContacts() // Пересканируем после получения разрешения
                case .denied, .restricted:
                    contactsPermissionStatus = .denied
                default:
                    contactsPermissionStatus = .notDetermined
                }
            } catch {
                contactsPermissionStatus = .denied
            }
        }
    }
    
    func requestCalendarPermission() {
        calendarPermissionStatus = .loading
        
        Task {
            await calendarService.requestCalendarAccess()
            let newStatus = calendarService.authorizationStatus
            
            if #available(iOS 17.0, *) {
                switch newStatus {
                case .fullAccess:
                    calendarPermissionStatus = .authorized
                    scanCalendar() // Пересканируем после получения разрешения
                case .denied, .restricted:
                    calendarPermissionStatus = .denied
                case .notDetermined:
                    calendarPermissionStatus = .notDetermined
                case .writeOnly:
                    calendarPermissionStatus = .denied
                @unknown default:
                    calendarPermissionStatus = .notDetermined
                }
            } else {
                switch newStatus {
                case .authorized, .fullAccess, .writeOnly:
                    calendarPermissionStatus = .authorized
                    scanCalendar() // Пересканируем после получения разрешения
                case .denied, .restricted:
                    calendarPermissionStatus = .denied
                case .notDetermined:
                    calendarPermissionStatus = .notDetermined
                @unknown default:
                    calendarPermissionStatus = .notDetermined
                }
            }
        }
    }
    
    /// Открывает настройки приложения
    func openAppSettings() {
        print("SCAN:TEST - Opening app settings")
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            print("SCAN:TEST - Failed to create settings URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                print("SCAN:TEST - Settings opened: \(success)")
            }
        } else {
            print("SCAN:TEST - Cannot open settings URL")
        }
    }
    
    func getSections(for type: MediaCleanerServiceType) -> [MediaCleanerServiceSection] {
        return mediaCleanerService.getMedia(type)
    }

    private func setupBindings() {
        print("SCAN:TEST - setupBindings started")
        
        mediaCleanerService.progressPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                print("SCAN:TEST - Progress received: \(progress.value), self exists: \(self != nil)")
                self?.progress = progress.value
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(mediaCleanerService.megabytesPublisher, mediaCleanerService.countsPublisher)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global())
            .receive(on: RunLoop.main)
            .sink { [weak self] megabytes, counts in
                print("SCAN:TEST - Counts/Megabytes received: total=\(counts.total), self exists: \(self != nil)")
                self?.counts = counts
                self?.megabytes = megabytes
                self?.subtitle = "\(counts.total) files • \(megabytes.total.formatAsFileSize()) will be cleaned"
            }
            .store(in: &cancellables)

        mediaCleanerService.previewsPublisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global())
            .receive(on: RunLoop.main)
            .sink { [weak self] previews in
                print("SCAN:TEST - Previews received, self exists: \(self != nil)")
                self?.previews = previews
            }
            .store(in: &cancellables)
        
        // Слушатель изменений количества контактов
        contactsViewModel.$contacts
            .receive(on: RunLoop.main)
            .sink { [weak self] contacts in
                print("SCAN:TEST - Contacts count received: \(contacts.count), self exists: \(self != nil)")
                self?.contactsCount = contacts.count
            }
            .store(in: &cancellables)
        
        // Слушатель изменений событий календаря
        calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                print("SCAN:TEST - Calendar events count received: \(events.count), self exists: \(self != nil)")
                self?.calendarEventsCount = events.count
            }
            .store(in: &cancellables)
        
        print("SCAN:TEST - setupBindings completed, total cancellables: \(cancellables.count)")
    }
}

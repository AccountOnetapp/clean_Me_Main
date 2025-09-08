//
//  CalendarService.swift
//  cleanme2
//
//  Created by AI Assistant on 18.08.25.
//

import Foundation
import EventKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var events: [SystemCalendarEvent] = []
    @Published var isLoading = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    private let whitelistService = WhitelistService()
    
    // MARK: - Initialization
    init() {
        print("🏁 [CalendarService] Инициализация CalendarService")
        checkAuthorizationStatus()
        setupWhitelistObserver()
        print("🏁 [CalendarService] Инициализация завершена")
    }
    
    private func setupWhitelistObserver() {
        print("🔗 [CalendarService.setupWhitelistObserver] Настраиваем наблюдатель за whitelist")
        print("🔗 [CalendarService.setupWhitelistObserver] WhitelistService содержит: \(whitelistService.whitelistedEvents.count) событий")
        
        // Наблюдаем за изменениями в whitelist для автоматического обновления
        whitelistService.$whitelistedEvents
            .sink { [weak self] whitelistedEvents in
                print("🔗 [CalendarService.setupWhitelistObserver.sink] Получено обновление whitelist: \(whitelistedEvents.count) событий")
                // При изменении whitelist обновляем статус событий
                Task { @MainActor in
                    self?.updateEventsWhitelistStatus()
                }
            }
            .store(in: &cancellables)
        
        // Принудительно обновляем статус при инициализации (на случай если данные уже загружены)
        print("🔗 [CalendarService.setupWhitelistObserver] Принудительно обновляем статус")
        Task { @MainActor in
            self.updateEventsWhitelistStatus()
        }
    }
    
    @MainActor
    private func updateEventsWhitelistStatus() {
        let whitelistedIdentifiers = whitelistService.getWhitelistedEventIdentifiers()
        print("🔄 [CalendarService.updateEventsWhitelistStatus] Обновляем whitelist статус для \(events.count) событий")
        print("🔄 [CalendarService.updateEventsWhitelistStatus] Whitelist содержит: \(whitelistedIdentifiers.count) идентификаторов")
        
        if !whitelistedIdentifiers.isEmpty {
            print("🔄 [CalendarService.updateEventsWhitelistStatus] Первые 3 whitelist ID:")
            for (i, id) in whitelistedIdentifiers.prefix(3).enumerated() {
                print("   \(i+1). '\(id)'")
            }
        }
        
        var updatedCount = 0
        var matchedCount = 0
        
        for index in events.indices {
            // Создаем составной идентификатор для проверки
            let compositeIdentifier = events[index].eventIdentifier
            let isWhitelisted = whitelistedIdentifiers.contains(compositeIdentifier)
            
            if isWhitelisted {
                matchedCount += 1
                print("🔄 [CalendarService.updateEventsWhitelistStatus] Найдено совпадение: '\(events[index].title)' (\(compositeIdentifier))")
            }
            
            if events[index].isWhiteListed != isWhitelisted {
                events[index].isWhiteListed = isWhitelisted
                updatedCount += 1
                print("🔄 [CalendarService.updateEventsWhitelistStatus] Обновлен статус для '\(events[index].title)': \(isWhitelisted)")
            }
            
            // Если событие добавлено в whitelist, убираем отметку спама
            if isWhitelisted {
                events[index].isMarkedAsSpam = false
            }
        }
        
        print("🔄 [CalendarService.updateEventsWhitelistStatus] Найдено совпадений: \(matchedCount)")
        print("🔄 [CalendarService.updateEventsWhitelistStatus] Обновлено событий: \(updatedCount)")
    }
    
    // MARK: - Public Methods
    
    /// Запрашивает разрешение на доступ к календарю
    func requestCalendarAccess() async {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.authorizationStatus = granted ? .fullAccess : .denied
                    if granted {
                        Task {
                            await self.loadEvents()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                    self.authorizationStatus = .denied
                }
            }
        } else {
            // Используем старый API для iOS 16 и ниже
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    Task { @MainActor in
                        if let error = error {
                            self.errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                            self.authorizationStatus = .denied
                        } else {
                            self.authorizationStatus = granted ? .authorized : .denied
                            if granted {
                                Task {
                                    await self.loadEvents()
                                }
                            }
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    /// Загружает события из системного календаря
    func loadEvents(from startDate: Date? = nil, to endDate: Date? = nil) async {
        let hasAccess = if #available(iOS 17.0, *) {
            authorizationStatus == .fullAccess
        } else {
            authorizationStatus == .authorized
        }
        
        guard hasAccess else {
            await requestCalendarAccess()
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let end = endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        let whitelistedIdentifiers = whitelistService.getWhitelistedEventIdentifiers()
        print("🔄 [CalendarService.loadEvents] Загружено \(ekEvents.count) событий из системного календаря")
        print("🔄 [CalendarService.loadEvents] Whitelist содержит: \(whitelistedIdentifiers.count) идентификаторов")
        
        var whitelistedCount = 0
        let systemEvents = ekEvents.map { ekEvent in
            // Создаем составной идентификатор для проверки whitelist статуса
            let compositeIdentifier = "\(ekEvent.eventIdentifier)_\(ekEvent.startDate.timeIntervalSince1970)"
            let isWhitelisted = whitelistedIdentifiers.contains(compositeIdentifier)
            if isWhitelisted {
                whitelistedCount += 1
                print("🔄 [CalendarService.loadEvents] Найдено whitelisted событие: '\(ekEvent.title)' (\(compositeIdentifier))")
            }
            return SystemCalendarEvent(from: ekEvent, isWhitelisted: isWhitelisted)
        }.sorted(by: { $0.startDate > $1.startDate }) // Сортировка от новых к старым
        
        print("🔄 [CalendarService.loadEvents] Создано \(systemEvents.count) SystemCalendarEvent, из них whitelisted: \(whitelistedCount)")
        
        await MainActor.run {
            self.events = systemEvents
            self.isLoading = false
            self.updateEventsWhitelistStatus()
        }
    }
    
    /// Удаляет событие из системного календаря
    func deleteEvent(_ event: SystemCalendarEvent) async -> EventDeletionResult {
        print("🗑️ [CalendarService] Удаляем событие: '\(event.title)' (\(event.eventIdentifier))")
        
        let hasAccess = if #available(iOS 17.0, *) {
            authorizationStatus == .fullAccess
        } else {
            authorizationStatus == .authorized
        }
        
        guard hasAccess else {
            print("❌ [CalendarService] Нет разрешений для удаления")
            return .failed(.noPermission)
        }
        
        // Извлекаем оригинальный eventIdentifier из составного
        let originalEventIdentifier: String
        if event.eventIdentifier.contains("_") {
            originalEventIdentifier = String(event.eventIdentifier.split(separator: "_").first ?? "")
        } else {
            originalEventIdentifier = event.eventIdentifier
        }
        
        print("🔍 [CalendarService] Ищем событие с оригинальным ID: '\(originalEventIdentifier)'")
        
        // Находим оригинальное EKEvent
        guard let ekEvent = eventStore.event(withIdentifier: originalEventIdentifier) else {
            print("❌ [CalendarService] Событие не найдено в системном календаре по ID: '\(originalEventIdentifier)'")
            return .failed(.eventNotFound)
        }
        
        // Проверяем, можно ли удалить событие
        if !canDeleteEvent(ekEvent) {
            let reason = getCannotDeleteReason(ekEvent)
            print("❌ [CalendarService] Событие нельзя удалить: \(reason)")
            return .failed(.cannotDelete(reason: reason))
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
            print("✅ [CalendarService] Событие успешно удалено из системного календаря")
            
            // Обновляем локальный массив
            await MainActor.run {
                let beforeCount = self.events.count
                self.events.removeAll {
                    $0.eventIdentifier == event.eventIdentifier &&
                    Calendar.current.isDate($0.startDate, inSameDayAs: event.startDate)
                }
                let afterCount = self.events.count
                print("🗑️ [CalendarService] Удалено событие '\(event.title)' из локального массива (\(beforeCount) -> \(afterCount))")
            }
            
            return .success
        } catch {
            print("❌ [CalendarService] Ошибка удаления: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
            return .failed(.systemError(error))
        }
    }
    
    /// Проверяет, можно ли удалить событие
    private func canDeleteEvent(_ ekEvent: EKEvent) -> Bool {
        // Проверяем, является ли календарь доступным для записи
        guard ekEvent.calendar.allowsContentModifications else {
            return false
        }
        
        // Проверяем, не является ли это событием из общего календаря с ограничениями
        if ekEvent.calendar.type == .subscription || ekEvent.calendar.type == .birthday {
            return false
        }
        
        // Проверяем, не является ли это событием, созданным другим пользователем в общем календаре
        if ekEvent.calendar.type == .calDAV && ekEvent.organizer != nil {
            // Если есть организатор и это не текущий пользователь
            if let organizer = ekEvent.organizer,
               let currentUserEmail = getCurrentUserEmail(),
               !organizer.url.absoluteString.contains(currentUserEmail) {
                return false
            }
        }
        
        return true
    }
    
    /// Получает причину, по которой событие нельзя удалить
    private func getCannotDeleteReason(_ ekEvent: EKEvent) -> String {
        if !ekEvent.calendar.allowsContentModifications {
            return "'\(ekEvent.calendar.title)' calendar is read-only and doesn't allow modifications."
        }
        
        if ekEvent.calendar.type == .subscription {
            return "'\(ekEvent.calendar.title)' calendar cannot be deleted.\n\nBut you can delete the account that owns this calendar. You can learn detailed steps from our guide on how to get rid of suspicious or unwanted event sources in your calendar."
        }
        
        if ekEvent.calendar.type == .birthday {
            return "Birthday events cannot be deleted from the calendar."
        }
        
        if ekEvent.calendar.type == .calDAV && ekEvent.organizer != nil {
            if let organizer = ekEvent.organizer {
                let organizerName = organizer.name ?? "another user"
                return "'\(organizerName)' calendar cannot be deleted.\n\nBut you can delete the account that owns this calendar. You can learn detailed steps from our guide on how to get rid of suspicious or unwanted event sources in your calendar."
            }
        }
        
        return "This event cannot be deleted due to calendar restrictions."
    }
    
    /// Получает email текущего пользователя (упрощенная версия)
    private func getCurrentUserEmail() -> String? {
        // В реальном приложении здесь была бы логика получения email текущего пользователя
        // Например, из настроек аккаунта или системных настроек
        return nil
    }
    
    /// Удаляет несколько событий
    func deleteEvents(_ eventsToDelete: [SystemCalendarEvent]) async -> EventsDeletionResult {
        var deletedCount = 0
        var failedEvents: [(SystemCalendarEvent, EventDeletionError)] = []
        
        for event in eventsToDelete {
            let result = await deleteEvent(event)
            switch result {
            case .success:
                deletedCount += 1
            case .failed(let error):
                failedEvents.append((event, error))
            }
        }
        
        return EventsDeletionResult(
            deletedCount: deletedCount,
            totalCount: eventsToDelete.count,
            failedEvents: failedEvents
        )
    }
    
    /// Помечает событие как спам (добавляет в заметки)
    func markAsSpam(_ event: SystemCalendarEvent) async -> Bool {
        let hasAccess = if #available(iOS 17.0, *) {
            authorizationStatus == .fullAccess
        } else {
            authorizationStatus == .authorized
        }
        
        guard hasAccess else { return false }
        
        guard let ekEvent = eventStore.event(withIdentifier: event.eventIdentifier) else {
            return false
        }
        
        do {
            ekEvent.notes = (ekEvent.notes ?? "") + "\n[MARKED_AS_SPAM]"
            try eventStore.save(ekEvent, span: .thisEvent)
            
            // Обновляем локальное событие
            await MainActor.run {
                if let index = self.events.firstIndex(where: { $0.id == event.id }) {
                    self.events[index].isMarkedAsSpam = true
                }
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to mark event as spam: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Добавляет событие в локальный белый список
    func addToWhiteList(_ event: SystemCalendarEvent) async -> Bool {
        // Добавляем в локальный whitelist через WhitelistService
        whitelistService.addToWhitelist(event)
        
        // Обновляем локальное событие
        await MainActor.run {
            if let index = self.events.firstIndex(where: {
                $0.eventIdentifier == event.eventIdentifier &&
                Calendar.current.isDate($0.startDate, inSameDayAs: event.startDate)
            }) {
                print("🔄 [CalendarService] Обновляем статус события '\(self.events[index].title)' -> isWhiteListed = true")
                self.events[index].isWhiteListed = true
                self.events[index].isMarkedAsSpam = false
            } else {
                print("❌ [CalendarService] Не найдено событие для обновления статуса: '\(event.title)'")
            }
        }
        
        return true
    }
    
    /// Удаляет событие из локального белого списка
    func removeFromWhiteList(_ event: SystemCalendarEvent) async -> Bool {
        // Удаляем из локального whitelist
        whitelistService.removeFromWhitelist(event)
        
        // Обновляем локальное событие
        await MainActor.run {
            if let index = self.events.firstIndex(where: {
                $0.eventIdentifier == event.eventIdentifier &&
                Calendar.current.isDate($0.startDate, inSameDayAs: event.startDate)
            }) {
                print("🔄 [CalendarService] Обновляем статус события '\(self.events[index].title)' -> isWhiteListed = false")
                self.events[index].isWhiteListed = false
            } else {
                print("❌ [CalendarService] Не найдено событие для обновления статуса: '\(event.title)'")
            }
        }
        
        return true
    }
    
    /// Получает статистику событий
    func getEventsStatistics() -> EventsStatistics {
        let total = events.count
        let spam = events.filter { $0.isMarkedAsSpam }.count
        let whitelisted = events.filter { $0.isWhiteListed }.count
        let regular = total - spam - whitelisted
        
        return EventsStatistics(
            total: total,
            spam: spam,
            whitelisted: whitelisted,
            regular: regular
        )
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        print("🔐 [CalendarService.checkAuthorizationStatus] Статус разрешений: \(authorizationStatus)")
        
        let hasAccess = if #available(iOS 17.0, *) {
            authorizationStatus == .fullAccess
        } else {
            authorizationStatus == .authorized
        }
        
        print("🔐 [CalendarService.checkAuthorizationStatus] Есть доступ: \(hasAccess)")
        
        if hasAccess {
            print("🔐 [CalendarService.checkAuthorizationStatus] Загружаем события автоматически")
            Task {
                await loadEvents()
            }
        } else {
            print("🔐 [CalendarService.checkAuthorizationStatus] Нет доступа, события не загружаются")
        }
    }
}

// MARK: - Supporting Models

struct SystemCalendarEvent: Codable, Identifiable, Hashable {
    let id = UUID()
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendar: String
    let location: String?
    let notes: String?
    var isMarkedAsSpam: Bool
    var isWhiteListed: Bool
    
    init(from ekEvent: EKEvent, isWhitelisted: Bool = false) {
        self.eventIdentifier = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendar = ekEvent.calendar?.title ?? "Unknown Calendar"
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        
        // Проверяем отметки в заметках для спама
        let notesContent = ekEvent.notes ?? ""
        self.isMarkedAsSpam = notesContent.contains("[MARKED_AS_SPAM]")
        
        // Используем локальный whitelist
        self.isWhiteListed = isWhitelisted
    }
    
    // Обычный инициализатор для создания временных событий
    init(id: UUID = UUID(), eventIdentifier: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendar: String, location: String? = nil, notes: String? = nil, isMarkedAsSpam: Bool = false, isWhiteListed: Bool = false) {
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.location = location
        self.notes = notes
        self.isMarkedAsSpam = isMarkedAsSpam
        self.isWhiteListed = isWhiteListed
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: startDate)
        } else {
            formatter.dateFormat = "d MMM yyyy, HH:mm"
            return formatter.string(from: startDate)
        }
    }
    
    var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        }
    }
    
    var source: String {
        return calendar
    }
    
    // Для совместимости с существующим кодом
    var date: Date {
        return startDate
    }
}

struct EventsStatistics {
    let total: Int
    let spam: Int
    let whitelisted: Int
    let regular: Int
}

// MARK: - Event Deletion Models

enum EventDeletionResult {
    case success
    case failed(EventDeletionError)
}

enum EventDeletionError {
    case noPermission
    case eventNotFound
    case cannotDelete(reason: String)
    case systemError(Error)
    
    var localizedDescription: String {
        switch self {
        case .noPermission:
            return "No permission to access calendar"
        case .eventNotFound:
            return "Event not found in calendar"
        case .cannotDelete(let reason):
            return reason
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        }
    }
    
    var isUserActionRequired: Bool {
        switch self {
        case .cannotDelete:
            return true
        default:
            return false
        }
    }
}

struct EventsDeletionResult {
    let deletedCount: Int
    let totalCount: Int
    let failedEvents: [(SystemCalendarEvent, EventDeletionError)]
    
    var hasFailures: Bool {
        return !failedEvents.isEmpty
    }
    
    var cannotDeleteEvents: [(SystemCalendarEvent, EventDeletionError)] {
        return failedEvents.filter { $0.1.isUserActionRequired }
    }
    
    var hasCannotDeleteEvents: Bool {
        return !cannotDeleteEvents.isEmpty
    }
}

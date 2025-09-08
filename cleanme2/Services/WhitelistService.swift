//
//  WhitelistService.swift
//  cleanme2
//
//  Created by AI Assistant on 18.08.25.
//

import Foundation
import CoreData
import Combine

@MainActor
final class WhitelistService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var whitelistedEvents: [SystemCalendarEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let whitelistKey = "whitelistedEvents"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        print("🏁 [WhitelistService] Инициализация WhitelistService")
        loadWhitelistedEvents()
        print("🏁 [WhitelistService] Инициализация завершена, загружено событий: \(whitelistedEvents.count)")
    }
    
    // MARK: - Public Methods
    
    /// Добавляет событие в локальный whitelist (UserDefaults)
    func addToWhitelist(_ event: SystemCalendarEvent) {
        print("🔍 [WhitelistService] Добавляем событие в whitelist:")
        print("🔍 [WhitelistService]   - Название: '\(event.title)'")
        print("🔍 [WhitelistService]   - Оригинальный ID: '\(event.eventIdentifier)'")
        
        // Проверяем, не добавлено ли уже это событие
        if isEventWhitelisted(event) {
            print("⚠️ [WhitelistService] Событие уже в whitelist, пропускаем")
            return
        }
        
        // Добавляем событие в локальный массив и сохраняем
        var eventToAdd = event
        eventToAdd.isWhiteListed = true
        whitelistedEvents.append(eventToAdd)
        saveWhitelistedEvents()
        print("✅ [WhitelistService] Событие успешно добавлено и сохранено в UserDefaults")
        print("🔄 [WhitelistService] Whitelist обновлен, всего записей: \(whitelistedEvents.count)")
    }
    
    /// Удаляет событие из локального whitelist (UserDefaults)
    func removeFromWhitelist(_ event: SystemCalendarEvent) {
        let beforeCount = whitelistedEvents.count
        whitelistedEvents.removeAll { $0.eventIdentifier == event.eventIdentifier }
        saveWhitelistedEvents()
        let afterCount = whitelistedEvents.count
        print("🗑️ [WhitelistService] Удалено событие из whitelist. До: \(beforeCount), После: \(afterCount)")
    }
    
    /// Проверяет, находится ли событие в whitelist
    func isEventWhitelisted(_ event: SystemCalendarEvent) -> Bool {
        return whitelistedEvents.contains { $0.eventIdentifier == event.eventIdentifier }
    }
    
    /// Получает все события из whitelist по идентификаторам
    func getWhitelistedEventIdentifiers() -> Set<String> {
        let identifiers = Set(whitelistedEvents.map { $0.eventIdentifier })
        print("🔍 [WhitelistService.getWhitelistedEventIdentifiers] Возвращаем \(identifiers.count) идентификаторов.")
        return identifiers
    }
    
    /// Очищает весь whitelist
    func clearWhitelist() {
        whitelistedEvents = []
        saveWhitelistedEvents()
        print("🧹 [WhitelistService] Whitelist очищен")
    }
    
    /// Получает статистику whitelist
    func getWhitelistStatistics() -> WhitelistStatistics {
        let total = whitelistedEvents.count
        let thisWeek = whitelistedEvents.filter { event in
            return Calendar.current.isDate(event.startDate, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
        
        return WhitelistStatistics(total: total, addedThisWeek: thisWeek)
    }
    
    // MARK: - Private Methods
    
    private func saveWhitelistedEvents() {
        do {
            let encodedData = try JSONEncoder().encode(whitelistedEvents)
            userDefaults.set(encodedData, forKey: whitelistKey)
        } catch {
            print("❌ [WhitelistService] Ошибка кодирования событий: \(error.localizedDescription)")
            errorMessage = "Failed to save whitelist: \(error.localizedDescription)"
        }
    }
    
    private func loadWhitelistedEvents() {
        isLoading = true
        errorMessage = nil
        
        if let savedData = userDefaults.data(forKey: whitelistKey) {
            do {
                whitelistedEvents = try JSONDecoder().decode([SystemCalendarEvent].self, from: savedData)
                print("🔄 [WhitelistService.loadWhitelistedEvents] Загружено событий из UserDefaults: \(whitelistedEvents.count)")
            } catch {
                print("❌ [WhitelistService.loadWhitelistedEvents] Ошибка декодирования событий: \(error.localizedDescription)")
                errorMessage = "Failed to load whitelist: \(error.localizedDescription)"
                whitelistedEvents = []
            }
        } else {
            whitelistedEvents = []
            print("🔄 [WhitelistService.loadWhitelistedEvents] UserDefaults пуст")
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Models

struct WhitelistStatistics {
    let total: Int
    let addedThisWeek: Int
}

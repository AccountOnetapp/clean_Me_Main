//
//  CalendarEvent.swift
//  cleanme2
//

import SwiftUI

// MARK: - Legacy Data Model (for backward compatibility)
struct CalendarEvent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let source: String
    let date: Date
    let eventIdentifier: String // Уникальный идентификатор события из системного календаря
    var isWhiteListed: Bool = false
    var isMarkedAsSpam: Bool = false
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    // Извлекает оригинальный eventIdentifier из составного ключа
    var originalEventIdentifier: String {
        if eventIdentifier.contains("_") {
            return String(eventIdentifier.split(separator: "_").first ?? "")
        }
        return eventIdentifier
    }
    
    // Инициализатор для создания из SystemCalendarEvent
    init(from systemEvent: SystemCalendarEvent) {
        self.title = systemEvent.title
        self.source = systemEvent.calendar // Используем calendar как source
        self.date = systemEvent.startDate // Используем startDate как date
        // Создаем уникальный идентификатор из eventIdentifier + startDate для повторяющихся событий
        self.eventIdentifier = "\(systemEvent.eventIdentifier)_\(systemEvent.startDate.timeIntervalSince1970)"
        self.isWhiteListed = systemEvent.isWhiteListed
        self.isMarkedAsSpam = systemEvent.isMarkedAsSpam
    }
    
    // Обычный инициализатор
    init(title: String, source: String, date: Date, eventIdentifier: String = UUID().uuidString, isWhiteListed: Bool = false, isMarkedAsSpam: Bool = false) {
        self.title = title
        self.source = source
        self.date = date
        self.eventIdentifier = eventIdentifier
        self.isWhiteListed = isWhiteListed
        self.isMarkedAsSpam = isMarkedAsSpam
    }
}

let sampleEvents = [
    CalendarEvent(title: "Free webinar on home dentistry.", source: "mail@mail.ru", date: createDate(year: 2024, month: 5, day: 15)),
    CalendarEvent(title: "Birthday of Konstantin", source: "mail@mail.ru", date: createDate(year: 2024, month: 6, day: 20)),
    CalendarEvent(title: "Development Daily Meet", source: "Calendar", date: createDate(year: 2024, month: 7, day: 5)),
    CalendarEvent(title: "Free webinar on home dentistry.", source: "mail@mail.ru", date: createDate(year: 2024, month: 8, day: 10)),
    CalendarEvent(title: "Birthday of Konstantin", source: "mail@mail.ru", date: createDate(year: 2025, month: 1, day: 25)),
    CalendarEvent(title: "Development Daily Meet", source: "Calendar", date: createDate(year: 2025, month: 3, day: 1)),
    CalendarEvent(title: "Team Sync-up", source: "Calendar", date: createDate(year: 2024, month: 9, day: 1)),
    CalendarEvent(title: "Project Review", source: "mail@mail.ru", date: createDate(year: 2025, month: 2, day: 15)),
    CalendarEvent(title: "Spam Event 1", source: "spam@example.com", date: createDate(year: 2024, month: 11, day: 2)),
    CalendarEvent(title: "Spam Event 2", source: "spam@example.com", date: createDate(year: 2025, month: 4, day: 10))
]

// Helper function to create a Date from components
func createDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components) ?? Date()
}

// MARK: - Preview
#Preview {
    CalendarView()
}

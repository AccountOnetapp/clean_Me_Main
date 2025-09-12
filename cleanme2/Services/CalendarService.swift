//
//  CalendarService.swift
//  cleanme2
//
//  Created by AI Assistant on 18.08.25.
//

import Foundation
import EventKit
import Combine

// MARK: - Constants & Utilities

private struct CalendarConstants {
    static let spamMarker = "[MARKED_AS_SPAM]"
    static let backupIdentifierSeparator = "_"
}

private extension EKEvent {
    /// Checks if a calendar event can be deleted.
    func isDeletable() -> Bool {
        // Can't delete if calendar is read-only
        guard calendar.allowsContentModifications else { return false }
        
        // Cannot delete birthday or subscription events
        if calendar.type == .birthday || calendar.type == .subscription {
            return false
        }
        
        // Cannot delete if it's an event organized by someone else in a shared calendar
        if self.organizer != nil, calendar.type == .calDAV {
            // NOTE: A real app would get the current user's email securely.
            // For now, we assume if an organizer exists, it's not deletable.
            return false // Or add specific logic to check if organizer is current user
        }
        
        return true
    }
    
    /// Returns a human-readable reason why an event cannot be deleted.
    func deletionRestrictionReason() -> String {
        if !calendar.allowsContentModifications {
            return "'\(calendar.title)' calendar is read-only and doesn't allow modifications."
        }
        
        if calendar.type == .subscription {
            return "This subscription calendar cannot be deleted. To remove these events, you must delete the source account from your device settings."
        }
        
        if calendar.type == .birthday {
            return "Birthday events cannot be deleted from the calendar."
        }
        
        if let organizer = self.organizer, calendar.type == .calDAV {
            let organizerName = organizer.name ?? "another user"
            return "This event is from a shared calendar and cannot be deleted. It was organized by \(organizerName)."
        }
        
        return "This event cannot be deleted due to calendar restrictions."
    }
}

// MARK: - Main Service Class

/// Manages all calendar event fetching, deletion, and whitelisting.
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
        checkAuthorizationStatus()
        setupWhitelistObserver()
    }
    
    // MARK: - Public API
    
    /// Requests calendar access and loads events if granted.
    func requestCalendarAccess() async {
        let accessType = EKEntityType.event
        let isAccessGranted: Bool
        
        do {
            if #available(iOS 17.0, *) {
                isAccessGranted = try await eventStore.requestFullAccessToEvents()
            } else {
                isAccessGranted = try await eventStore.requestAccess(to: accessType)
            }
            
            await handleAccessResult(granted: isAccessGranted)
        } catch {
            await handleAccessError(error)
        }
    }
    
    /// Loads events from the system calendar.
    func loadEvents(from startDate: Date? = nil, to endDate: Date? = nil) async {
        guard canAccessCalendar else {
            return await requestCalendarAccess()
        }
        
        isLoading = true
        errorMessage = nil
        
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let end = endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        let whitelistedIdentifiers = whitelistService.getWhitelistedEventIdentifiers()
        
        let systemEvents = ekEvents.map {
            let compositeId = "\($0.eventIdentifier ?? "")_\($0.startDate.timeIntervalSince1970)"
            let isWhitelisted = whitelistedIdentifiers.contains(compositeId)
            return SystemCalendarEvent(from: $0, isWhitelisted: isWhitelisted)
        }.sorted(by: { $0.startDate > $1.startDate })
        
        events = systemEvents
        isLoading = false
        updateEventsWhitelistStatus()
    }
    
    /// Deletes a single event from the system calendar.
    func deleteEvent(_ event: SystemCalendarEvent) async -> EventDeletionResult {
        guard canAccessCalendar else { return .failed(.noPermission) }
        
        guard let ekEvent = eventStore.event(withIdentifier: event.eventIdentifier) else {
            return .failed(.eventNotFound)
        }
        
        guard ekEvent.isDeletable() else {
            return .failed(.cannotDelete(reason: ekEvent.deletionRestrictionReason()))
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
            events.removeAll { $0.id == event.id }
            return .success
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            return .failed(.systemError(error))
        }
    }
    
    /// Deletes multiple events.
    func deleteEvents(_ eventsToDelete: [SystemCalendarEvent]) async -> EventsDeletionResult {
        var deletedCount = 0
        var failedEvents: [(SystemCalendarEvent, EventDeletionError)] = []
        
        for event in eventsToDelete {
            let result = await deleteEvent(event)
            if case let .failed(error) = result {
                failedEvents.append((event, error))
            } else {
                deletedCount += 1
            }
        }
        
        return EventsDeletionResult(
            deletedCount: deletedCount,
            totalCount: eventsToDelete.count,
            failedEvents: failedEvents
        )
    }
    
    /// Marks an event as spam by appending a special note to it.
    func markAsSpam(_ event: SystemCalendarEvent) async -> Bool {
        guard canAccessCalendar, let ekEvent = eventStore.event(withIdentifier: event.eventIdentifier) else {
            return false
        }
        
        do {
            ekEvent.notes = (ekEvent.notes ?? "") + "\n\(CalendarConstants.spamMarker)"
            try eventStore.save(ekEvent, span: .thisEvent)
            
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isMarkedAsSpam = true
            }
            return true
        } catch {
            errorMessage = "Failed to mark event as spam: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Adds an event to the local whitelist.
    func addToWhiteList(_ event: SystemCalendarEvent) {
        whitelistService.addToWhitelist(event)
        updateEventsWhitelistStatus()
    }
    
    /// Removes an event from the local whitelist.
    func removeFromWhiteList(_ event: SystemCalendarEvent) {
        whitelistService.removeFromWhitelist(event)
        updateEventsWhitelistStatus()
    }
    
    /// Gets a breakdown of event statistics.
    func getEventsStatistics() -> EventsStatistics {
        let spamCount = events.filter { $0.isMarkedAsSpam }.count
        let whitelistedCount = events.filter { $0.isWhiteListed }.count
        
        return EventsStatistics(
            total: events.count,
            spam: spamCount,
            whitelisted: whitelistedCount,
            regular: events.count - spamCount - whitelistedCount
        )
    }
    
    // MARK: - Private Helpers
    
    private var canAccessCalendar: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if canAccessCalendar {
            Task { await loadEvents() }
        }
    }
    
    private func setupWhitelistObserver() {
        whitelistService.$whitelistedEvents
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateEventsWhitelistStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateEventsWhitelistStatus() {
        let whitelistedIdentifiers = whitelistService.getWhitelistedEventIdentifiers()
        
        for index in events.indices {
            let compositeIdentifier = events[index].eventIdentifier
            let isWhitelisted = whitelistedIdentifiers.contains(compositeIdentifier)
            
            // Check if status has changed to prevent unnecessary re-renders
            guard events[index].isWhiteListed != isWhitelisted else { continue }
            
            events[index].isWhiteListed = isWhitelisted
            
            // Whitelisting removes spam status
            if isWhitelisted {
                events[index].isMarkedAsSpam = false
            }
        }
    }
    
    private func handleAccessResult(granted: Bool) async {
        if #available(iOS 17.0, *) {
            authorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await loadEvents()
            }
        }
    }
    
    private func handleAccessError(_ error: Error) async {
        errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
        authorizationStatus = .denied
    }
}

// MARK: - Supporting Models

struct SystemCalendarEvent: Codable, Identifiable, Hashable {
    let id: UUID
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
        self.id = UUID()
        self.eventIdentifier = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendar = ekEvent.calendar?.title ?? "Unknown Calendar"
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.isMarkedAsSpam = (ekEvent.notes ?? "").contains(CalendarConstants.spamMarker)
        self.isWhiteListed = isWhitelisted
    }
    
    init(id: UUID = UUID(), eventIdentifier: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendar: String, location: String? = nil, notes: String? = nil, isMarkedAsSpam: Bool = false, isWhiteListed: Bool = false) {
        self.id = id
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
        formatter.dateFormat = isAllDay ? "d MMM yyyy" : "d MMM yyyy, HH:mm"
        return formatter.string(from: startDate)
    }
    
    var formattedTimeRange: String {
        if isAllDay {
            return "All day"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

// Other supporting structures remain the same as they are already well-defined.
struct EventsStatistics {
    let total: Int
    let spam: Int
    let whitelisted: Int
    let regular: Int
}

enum EventDeletionResult {
    case success
    case failed(EventDeletionError)
}

enum EventDeletionError: Error {
    case noPermission
    case eventNotFound
    case cannotDelete(reason: String)
    case systemError(Error)
    
    var localizedDescription: String {
        switch self {
        case .noPermission: return "No permission to access calendar"
        case .eventNotFound: return "Event not found in calendar"
        case .cannotDelete(let reason): return reason
        case .systemError(let error): return "System error: \(error.localizedDescription)"
        }
    }
    
    var isUserActionRequired: Bool {
        if case .cannotDelete = self { return true }
        return false
    }
}

struct EventsDeletionResult {
    let deletedCount: Int
    let totalCount: Int
    let failedEvents: [(SystemCalendarEvent, EventDeletionError)]
    
    var hasFailures: Bool { !failedEvents.isEmpty }
    var cannotDeleteEvents: [(SystemCalendarEvent, EventDeletionError)] { failedEvents.filter { $0.1.isUserActionRequired } }
    var hasCannotDeleteEvents: Bool { !cannotDeleteEvents.isEmpty }
}

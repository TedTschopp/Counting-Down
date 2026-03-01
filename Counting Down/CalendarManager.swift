//
//  CalendarManager.swift
//  ChronoEvent
//
//  Created by Assistant on 2/28/26.
//

import Foundation
import EventKit

/// Handles calendar authorization and event fetching using EventKit
@MainActor
final class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendarAccessGranted: Bool = false
    
    init() {
        refreshAuthorizationStatus()
    }
    
    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        calendarAccessGranted = (authorizationStatus == .authorized || authorizationStatus == .fullAccess)
    }
    
    /// Request full access to calendar events (iOS 17+)
    func requestFullAccess() async {
        do {
            if #available(iOS 17.0, *) {
                try await eventStore.requestFullAccessToEvents()
            } else {
                try await eventStore.requestAccess(to: .event)
            }
            refreshAuthorizationStatus()
        } catch {
            refreshAuthorizationStatus()
        }
    }
    
    /// Fetch events between two dates, optionally filtered by calendars
    func fetchEvents(startDate: Date, endDate: Date, calendars: [EKCalendar]? = nil) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        return eventStore.events(matching: predicate)
    }
    
    /// Fetch available calendars
    var availableCalendars: [EKCalendar] {
        eventStore.calendars(for: .event)
    }
}


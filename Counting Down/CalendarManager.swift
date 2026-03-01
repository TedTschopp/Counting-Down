//
//  CalendarManager.swift
//  ChronoEvent
//
//  Created by Assistant on 2/28/26.
//

import Foundation
import Combine
import EventKit
#if canImport(UIKit)
import UIKit
#endif

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
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status
        if #available(iOS 17.0, *) {
            // On iOS 17+, consider full access as granted. Write-only is not sufficient to read events.
            calendarAccessGranted = (status == .fullAccess)
        } else {
            // Prior to iOS 17, `.authorized` indicates read/write access.
            calendarAccessGranted = (status == .authorized)
        }
    }
    
    /// Request full access to calendar events (iOS 17+). Logs errors and updates status.
    func requestFullAccess() async {
        do {
            if #available(iOS 17.0, *) {
                try await eventStore.requestFullAccessToEvents()
            } else {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    eventStore.requestAccess(to: .event) { _, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            }
        } catch {
            print("Calendar permission request failed: \(error)")
        }
        // Always refresh status after attempting
        refreshAuthorizationStatus()
    }
    
    #if canImport(UIKit)
    /// Open this app's Settings screen so the user can change calendar permissions.
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    #endif
    
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


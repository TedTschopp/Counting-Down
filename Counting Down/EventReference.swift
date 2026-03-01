//
//  EventReference.swift
//  ChronoEvent
//
//  Created by Assistant on 2/28/26.
//

import Foundation
import SwiftData

/// Lightweight reference to a calendar event, with data minimization for privacy and widget usage
@Model
final class EventReference {
    /// Unique identifier for the event from EventKit
    var eventIdentifier: String
    /// Title of the event (optional: user can choose to redact in privacy settings)
    var title: String?
    /// Date of the occurrence being tracked (start or end, depending on settings)
    var targetDate: Date
    /// Whether this is an all-day event
    var isAllDay: Bool
    /// Time zone identifier for the event
    var timeZoneIdentifier: String?
    /// User toggle for hiding title in widget/complication contexts
    var hideTitle: Bool
    /// Date when event was pinned (used for progress bar, e.g., track from 'now')
    var progressStartDate: Date?

    init(eventIdentifier: String, title: String?, targetDate: Date, isAllDay: Bool, timeZoneIdentifier: String?, hideTitle: Bool = false, progressStartDate: Date? = nil) {
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.targetDate = targetDate
        self.isAllDay = isAllDay
        self.timeZoneIdentifier = timeZoneIdentifier
        self.hideTitle = hideTitle
        self.progressStartDate = progressStartDate
    }
}

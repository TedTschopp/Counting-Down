//
//  ChronoEventWidget.swift
//  ChronoEventWidgetExtension
//
//  Created by Assistant on 2/28/26.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Timeline Entry
struct CountdownEntry: TimelineEntry {
    let date: Date
    let eventTitle: String?
    let targetDate: Date
    let isAllDay: Bool
    let isPrivacyRedacted: Bool
}

// MARK: - Provider
struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: Date(), eventTitle: "Sample Event", targetDate: Date().addingTimeInterval(3600 * 24), isAllDay: false, isPrivacyRedacted: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        // In a real app, load primary event from shared storage (App Group, SwiftData, etc.)
        let entry = CountdownEntry(date: Date(), eventTitle: "Sample Event", targetDate: Date().addingTimeInterval(3600 * 24), isAllDay: false, isPrivacyRedacted: false)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

#if os(iOS)
let supportedWidgetFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular]
#else
let supportedWidgetFamilies: [WidgetFamily] = [.systemSmall, .systemMedium]
#endif

// MARK: - Widget View
struct CountdownWidgetEntryView: View {
    var entry: CountdownProvider.Entry
    var body: some View {
        VStack(spacing: 8) {
            if let title = entry.eventTitle, !entry.isPrivacyRedacted {
                Text(title)
                    .font(.headline)
                    .privacySensitive(entry.isPrivacyRedacted)
            }
            WidgetTimerView(targetDate: entry.targetDate)
        }
        .padding()
    }
}

#if WIDGET_EXTENSION
// Only compile the widget entry point in the Widget Extension target.
// Add 'WIDGET_EXTENSION' to the extension's Active Compilation Conditions.
@main
struct ChronoEventWidget: Widget {
    let kind: String = "ChronoEventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .supportedFamilies(supportedWidgetFamilies)
        .configurationDisplayName("ChronoEvent")
        .description("See your event countdown anywhere.")
    }
}
#endif

// MARK: - WidgetTimerView for Widget
struct WidgetTimerView: View {
    let targetDate: Date
    var body: some View {
        // Use the system timer rendering for live updating
        Text(targetDate, style: .timer)
            .font(.largeTitle.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

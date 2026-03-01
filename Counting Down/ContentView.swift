//
//  ContentView.swift
//  Counting Down
//
//  Created by Ted Tschopp on 2/28/26.
//

import SwiftUI
import SwiftData
import EventKit
import Combine
import OSLog

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedEvents: [EventReference]
    
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedEvent: EKEvent? = nil
    @State private var primaryEventIdentifier: String? = nil
    @State private var showingEventPicker = false
    @State private var eventSearch = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            if !calendarManager.calendarAccessGranted {
                VStack(spacing: 24) {
                    Text("Connect Your Calendar")
                        .font(.title)
                        .bold()
                    Text("ChronoEvent needs access to your calendar to let you pick and pin events for countdowns.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Button("Connect Calendar") {
                        Task { await calendarManager.requestFullAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                    if calendarManager.authorizationStatus == .denied {
                        Text("Calendar access is denied. You can enable access in Settings.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            calendarManager.openAppSettings()
                        }
                    } else if #available(iOS 17.0, *), calendarManager.authorizationStatus == .writeOnly {
                        Text("Write-only access is insufficient to read your events. Please grant full access in Settings.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            calendarManager.openAppSettings()
                        }
                    }
                }
                .padding()
            } else if showingEventPicker || savedEvents.isEmpty {
                // Show event picker
                VStack(spacing: 8) {
                    Text("Select an Event")
                        .font(.title2)
                        .bold()
                    TextField("Search", text: $eventSearch)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    let now = Date()
                    let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
                    let end = Calendar.current.date(byAdding: .day, value: 365, to: now) ?? now
                    let events = calendarManager.fetchEvents(startDate: start, endDate: end)
                    let filteredEvents = events.filter {
                        eventSearch.isEmpty ||
                        ($0.title?.localizedCaseInsensitiveContains(eventSearch) ?? false)
                    }
                    if filteredEvents.isEmpty {
                        Text("No events found in the last 30 days or next year.")
                            .foregroundColor(.secondary)
                    } else {
                        List(filteredEvents, id: \.eventIdentifier) { event in
                            Button(action: {
                                addEventReference(for: event)
                                showingEventPicker = false
                            }) {
                                VStack(alignment: .leading) {
                                    Text(event.title ?? "(No Title)")
                                        .bold()
                                    Text(event.startDate, format: .dateTime)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !savedEvents.isEmpty {
                            Button("Cancel") {
                                showingEventPicker = false
                            }
                        }
                    }
                }
            } else {
                // Show list of pinned events
                List {
                    ForEach(savedEvents, id: \.eventIdentifier) { eventRef in
                        NavigationLink(value: eventRef.eventIdentifier) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(eventRef.title ?? "(No Title)")
                                        .bold()
                                    Text(eventRef.targetDate, format: .dateTime)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if eventRef.eventIdentifier == primaryEventIdentifier {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .accessibilityLabel("Primary Event")
                                } else {
                                    Button {
                                        setPrimaryEvent(eventRef)
                                    } label: {
                                        Image(systemName: "star")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Set as Primary Event")
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteEventReferences)
                }
                .navigationTitle("Pinned Events")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingEventPicker = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Event")
                    }
                }
                .navigationDestination(for: String.self) { eventIdentifier in
                    if let eventRef = savedEvents.first(where: { $0.eventIdentifier == eventIdentifier }) {
                        EventDetailView(eventRef: eventRef,
                                        isPrimary: eventRef.eventIdentifier == primaryEventIdentifier,
                                        onSetPrimary: {
                                            setPrimaryEvent(eventRef)
                                        },
                                        onDelete: {
                                            deleteEvent(eventRef)
                                        })
                    } else {
                        Text("Event not found")
                    }
                }
                .onAppear {
                    if primaryEventIdentifier == nil {
                        primaryEventIdentifier = savedEvents.first?.eventIdentifier
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                calendarManager.refreshAuthorizationStatus()
            }
        }
        .onChange(of: calendarManager.calendarAccessGranted) { _, granted in
            if granted && savedEvents.isEmpty {
                showingEventPicker = true
            }
        }
        .task {
            if calendarManager.calendarAccessGranted && savedEvents.isEmpty {
                showingEventPicker = true
            }
        }
    }
    
    private func addEventReference(for ekEvent: EKEvent) {
        guard let eventIdentifier = ekEvent.eventIdentifier else { return }
        if savedEvents.contains(where: { $0.eventIdentifier == eventIdentifier }) {
            // Already saved, ignore
            return
        }
        let newRef = EventReference(
            eventIdentifier: eventIdentifier,
            title: ekEvent.title,
            targetDate: ekEvent.startDate,
            isAllDay: ekEvent.isAllDay,
            timeZoneIdentifier: ekEvent.timeZone?.identifier,
            hideTitle: false,
            progressStartDate: Date()
        )
        modelContext.insert(newRef)
        if primaryEventIdentifier == nil {
            primaryEventIdentifier = newRef.eventIdentifier
        }
    }
    
    private func setPrimaryEvent(_ eventRef: EventReference) {
        withAnimation {
            primaryEventIdentifier = eventRef.eventIdentifier
        }
    }
    
    private func deleteEvent(_ eventRef: EventReference) {
        withAnimation {
            modelContext.delete(eventRef)
            if primaryEventIdentifier == eventRef.eventIdentifier {
                primaryEventIdentifier = savedEvents.first(where: { $0.eventIdentifier != eventRef.eventIdentifier })?.eventIdentifier
            }
        }
    }
    
    private func deleteEventReferences(offsets: IndexSet) {
        withAnimation {
            let toDelete = offsets.map { savedEvents[$0] }
            for eventRef in toDelete {
                modelContext.delete(eventRef)
                if primaryEventIdentifier == eventRef.eventIdentifier {
                    primaryEventIdentifier = savedEvents.first(where: { $0.eventIdentifier != eventRef.eventIdentifier })?.eventIdentifier
                }
            }
        }
    }
}

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    var eventRef: EventReference
    var isPrimary: Bool
    var onSetPrimary: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text(eventRef.title ?? "(No Title)")
                .font(.title2)
                .bold()
                .privacySensitive()
            TimerView(targetDate: eventRef.targetDate)
            Text("Event at \(eventRef.targetDate.formatted(.dateTime))")
                .font(.footnote)
            
            HStack(spacing: 20) {
                if !isPrimary {
                    Button(action: onSetPrimary) {
                        Label("Set as Primary", systemImage: "star")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Label("Primary Event", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Event", systemImage: "trash")
                }
            }
            .padding(.top, 20)
        }
        .padding()
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TimerView: View {
    let targetDate: Date
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let interval = targetDate.timeIntervalSince(now)
        let absInterval = abs(Int(interval))
        let (days, hours, minutes, seconds) = (
            absInterval / 86400,
            (absInterval % 86400) / 3600,
            (absInterval % 3600) / 60,
            absInterval % 60
        )
        VStack(spacing: 8) {
            if interval > 1 {
                Text("In\n\(days)d \(hours)h \(minutes)m \(seconds)s")
                    .multilineTextAlignment(.center)
                    .font(.largeTitle.monospacedDigit())
                    .foregroundColor(.blue)
            } else if interval < -1 {
                Text("Since\n\(days)d \(hours)h \(minutes)m \(seconds)s")
                    .multilineTextAlignment(.center)
                    .font(.largeTitle.monospacedDigit())
                    .foregroundColor(.green)
            } else {
                Text("Now")
                    .font(.largeTitle.bold())
            }
        }
        .onReceive(timer) { _ in now = Date() }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: EventReference.self, inMemory: true)
}

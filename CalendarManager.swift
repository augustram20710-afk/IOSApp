import Foundation
import EventKit
import Combine

final class CalendarManager: ObservableObject {
    private let store = EKEventStore()
    @Published var events: [EventItem] = []

    func requestAccessIfNeeded() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            store.requestAccess(to: .event) { granted, error in
                if granted { self.loadToday() }
            }
        case .authorized:
            loadToday()
        default:
            break
        }
    }

    func loadToday() {
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        let items = ekEvents.compactMap { ek -> EventItem? in
            guard let start = ek.startDate else { return nil }
            return EventItem(id: ek.eventIdentifier, title: ek.title ?? "(No title)", startDate: start, locationName: ek.location ?? "")
        }
        DispatchQueue.main.async {
            self.events = items.sorted { $0.startDate < $1.startDate }
        }
    }

    /// Add a local event (not persisted to system calendar) for the prototype UI.
    func addLocalEvent(title: String, startDate: Date, locationName: String) {
        let id = UUID().uuidString
        let ev = EventItem(id: id, title: title, startDate: startDate, locationName: locationName)
        DispatchQueue.main.async {
            self.events.append(ev)
            self.events.sort { $0.startDate < $1.startDate }
        }
    }
}

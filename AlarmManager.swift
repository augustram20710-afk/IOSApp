import Foundation
import UserNotifications
import CoreLocation
import Combine
import BackgroundTasks
import MapKit

final class AlarmManager: ObservableObject {
    private let calendar: CalendarManager
    private let map: MapManager
    private let location: LocationManager
    private let settings: SettingsManager
    private var cancellables = Set<AnyCancellable>()

    // user-configurable buffers (seconds) — provided by SettingsManager
    var departureSnooze: TimeInterval = 10 * 60 // 10 minutes

    // track known event IDs so we can cancel notifications for removed events
    private var knownEventIDs: Set<String> = [] {
        didSet { saveKnownEventIDs() }
    }

    private let knownIDsKey = "AlarmManager.KnownEventIDs"

    init(calendar: CalendarManager, map: MapManager, location: LocationManager, settings: SettingsManager) {
        self.calendar = calendar
        self.map = map
        self.location = location
        self.settings = settings

        loadKnownEventIDs()

        // Subscribe to calendar events changes to cancel notifications for removed events
        calendar.$events
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                let currentIDs = Set(events.map { $0.id })
                self.cancelNotificationsForRemovedEvents(currentEventIDs: currentIDs)
            }
            .store(in: &cancellables)
        // register background refresh task
        registerBackgroundTask()
        // observe settings for changes
        settings.$morningBuffer
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // when the morning buffer changes, reschedule upcoming alarms
                self?.rescheduleAllUpcomingEvents()
            }
            .store(in: &cancellables)

        settings.$transportMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // transport mode affects ETA estimation — reschedule accordingly
                self?.rescheduleAllUpcomingEvents()
            }
            .store(in: &cancellables)

        settings.$refreshDistanceThreshold
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.refreshDistanceThreshold = v }
            .store(in: &cancellables)
        // subscribe to location updates to trigger ETA refresh on movement
        location.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                guard let self = self else { return }
                self.maybeTriggerRefresh(for: loc)
            }
            .store(in: &cancellables)
    }

    private var currentTransport: MKDirectionsTransportType {
        switch settings.transportMode {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let e = error { print("Notification auth error:", e) }
        }
    }

    // MARK: - Background refresh (BGAppRefresh)

    // BGTask identifier -- add this identifier to your app's Info.plist under
    // `BGTaskSchedulerPermittedIdentifiers` and enable Background Modes -> Background fetch
    private let bgTaskIdentifier = "com.example.contextalarm.refresh"

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskIdentifier, using: nil) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            self?.handleAppRefresh(task: task)
        }
    }

    func scheduleAppRefresh(earliest: TimeInterval = 15 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliest)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: ", error)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh(earliest: 30 * 60) // schedule the next refresh

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation { [weak self] in
            let sem = DispatchSemaphore(value: 0)
            self?.performETARefresh { success in
                sem.signal()
            }
            // wait until our refresh completes or the task expires
            _ = sem.wait(timeout: .now() + 25)
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        queue.addOperation(operation)
    }

    /// Recalculate ETAs for upcoming events and reschedule notifications where needed.
    /// Calls completion(true) when finished.
    func performETARefresh(completion: @escaping (Bool) -> Void) {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now.addingTimeInterval(12*3600)

        // snapshot events
        let upcoming = calendar.events.filter { $0.startDate > now && $0.startDate <= horizon }
        guard !upcoming.isEmpty else { completion(true); return }

        let group = DispatchGroup()
        var anyFailed = false

        for ev in upcoming {
            group.enter()

            func finalize(updatedETA: TimeInterval?) {
                DispatchQueue.main.async {
                    if let idx = self.calendar.events.firstIndex(of: ev) {
                        self.calendar.events[idx].estimatedTravelTime = updatedETA
                        // schedule/reschedule alarms for this event
                        self.scheduleAlarm(for: self.calendar.events[idx])
                    }
                    group.leave()
                }
            }

            // If event already has coordinates, estimate directly
            if let coord = ev.coordinate {
                map.estimateTravelTime(to: coord, transportType: currentTransport) { eta in
                    if eta == nil { anyFailed = true }
                    finalize(updatedETA: eta)
                }
            } else if !ev.locationName.isEmpty {
                // geocode then estimate
                map.geocode(ev.locationName) { placemark in
                    guard let p = placemark, let coord = p.location?.coordinate else {
                        anyFailed = true
                        finalize(updatedETA: nil)
                        return
                    }
                    self.map.estimateTravelTime(to: coord, transportType: self.currentTransport) { eta in
                        if eta == nil { anyFailed = true }
                        finalize(updatedETA: eta)
                    }
                }
            } else {
                // no location available
                anyFailed = true
                finalize(updatedETA: nil)
            }
        }

        group.notify(queue: .global()) {
            completion(!anyFailed)
        }
    }

    // MARK: - Location-triggered refresh

    private var lastRefreshLocation: CLLocation?
    private var refreshDistanceThreshold: CLLocationDistance = 500 // meters
    private func maybeTriggerRefresh(for location: CLLocation) {
        // if we don't have a last refresh location, trigger the first refresh
        if let last = lastRefreshLocation {
            let d = location.distance(from: last)
            if d < refreshDistanceThreshold { return }
        }
        lastRefreshLocation = location
        // perform a refresh on a background queue; do not block the caller
        DispatchQueue.global(qos: .utility).async {
            let sem = DispatchSemaphore(value: 0)
            self.performETARefresh { _ in
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 20)
        }
    }

    /// Compute wake time for an event by subtracting travel time and morning buffer
    func computeWakeTime(for event: EventItem, travelTime: TimeInterval?) -> Date {
        let travel = travelTime ?? 0
        let morningBuffer = settings.morningBuffer
        return event.startDate.addingTimeInterval(-(travel + morningBuffer))
    }

    /// Schedules alarms for an event. This method first cancels any existing notifications for the event
    /// to avoid duplicates, then schedules wake and leave notifications if travel ETA is available.
    func scheduleAlarm(for event: EventItem) {
        // cancel any previous notifications for this event before scheduling
        cancelNotifications(forEventID: event.id)

        guard let eta = event.estimatedTravelTime else { return }

        let wakeDate = computeWakeTime(for: event, travelTime: eta)
        scheduleNotification(id: "wake_\(event.id)", title: "Wake for \(event.title)", body: "Wake now to reach your event at \(event.formattedStart())", at: wakeDate)

        let leaveDate = event.startDate.addingTimeInterval(-eta)
        scheduleNotification(id: "leave_\(event.id)", title: "Leave for \(event.title)", body: "Time to leave to reach your event on time.", at: leaveDate)

        // record that we've scheduled notifications for this event
        knownEventIDs.insert(event.id)
    }

    // MARK: - Cancellation / deduplication helpers

    func cancelNotifications(forEventID id: String) {
        let wake = "wake_\(id)"
        let leave = "leave_\(id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [wake, leave])
        // Also remove delivered notifications if present
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [wake, leave])
        knownEventIDs.remove(id)
    }

    /// Fetch pending notification requests (all)
    func fetchPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }

    /// Fetch pending notifications for a specific event ID (wake_ / leave_)
    func pendingNotifications(forEventID id: String, completion: @escaping ([UNNotificationRequest]) -> Void) {
        fetchPendingNotifications { requests in
            let filtered = requests.filter { $0.identifier == "wake_\(id)" || $0.identifier == "leave_\(id)" }
            completion(filtered)
        }
    }

    /// Reschedule alarm for an event by re-geocoding/estimating travel time and scheduling notifications.
    func rescheduleAlarm(for event: EventItem, completion: @escaping (Bool) -> Void) {
        // Cancel first
        cancelNotifications(forEventID: event.id)

        func scheduleWithETA(_ eta: TimeInterval?) {
            var updated = event
            updated.estimatedTravelTime = eta
            DispatchQueue.main.async {
                if let idx = self.calendar.events.firstIndex(of: event) {
                    self.calendar.events[idx].estimatedTravelTime = eta
                }
                self.scheduleAlarm(for: updated)
                completion(true)
            }
        }

        if let coord = event.coordinate {
                map.estimateTravelTime(to: coord, transportType: currentTransport) { eta in
                scheduleWithETA(eta)
            }
        } else if !event.locationName.isEmpty {
            map.geocode(event.locationName) { placemark in
                guard let p = placemark, let coord = p.location?.coordinate else { scheduleWithETA(nil); return }
                    self.map.estimateTravelTime(to: coord, transportType: self.currentTransport) { eta in
                    scheduleWithETA(eta)
                }
            }
        } else {
            scheduleWithETA(nil)
        }
    }

    /// Reschedule alarms for all upcoming events (from now forward).
    /// Calls completion(true) if all reschedules succeeded.
    func rescheduleAllUpcomingEvents(completion: ((Bool) -> Void)? = nil) {
        let now = Date()
        let upcoming = calendar.events.filter { $0.startDate > now }
        guard !upcoming.isEmpty else { completion?(true); return }

        let group = DispatchGroup()
        var anyFailed = false

        for ev in upcoming {
            group.enter()
            rescheduleAlarm(for: ev) { success in
                if !success { anyFailed = true }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(!anyFailed)
        }
    }

    private func cancelNotificationsForRemovedEvents(currentEventIDs: Set<String>) {
        let removed = knownEventIDs.subtracting(currentEventIDs)
        guard !removed.isEmpty else { return }
        for id in removed {
            cancelNotifications(forEventID: id)
        }
    }

    // MARK: - Persistence for known IDs

    private func loadKnownEventIDs() {
        if let arr = UserDefaults.standard.array(forKey: knownIDsKey) as? [String] {
            knownEventIDs = Set(arr)
        }
    }

    private func saveKnownEventIDs() {
        UserDefaults.standard.set(Array(knownEventIDs), forKey: knownIDsKey)
    }

    private func scheduleNotification(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let e = error { print("Error scheduling notification:\n", e) }
        }
    }

    /// Public helper to schedule a custom notification (used by UI helpers)
    func scheduleCustomNotification(id: String, title: String, body: String, at date: Date) {
        scheduleNotification(id: id, title: title, body: body, at: date)
    }
}

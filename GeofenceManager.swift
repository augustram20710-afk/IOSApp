import Foundation
import Combine
import MapKit
import UserNotifications

final class GeofenceManager: ObservableObject {
    @Published private(set) var rules: [GeofenceRule] = []

    private let storageKey = "GeofenceManager.Rules"
    private let locationManager: LocationManager
    private let mapManager: MapManager
    private var cancellables = Set<AnyCancellable>()

    init(locationManager: LocationManager, mapManager: MapManager) {
        self.locationManager = locationManager
        self.mapManager = mapManager
        loadRules()

        // Subscribe to region entry events
        locationManager.regionEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] region in
                self?.handleRegionEvent(region)
            }
            .store(in: &cancellables)

        // Start monitoring saved rules (attempt to geocode and start monitoring)
        for rule in rules where rule.enabled {
            startMonitoring(rule: rule)
        }
    }

    // Add a new rule: geocode address and begin monitoring
    func addRule(name: String, address: String, radius: Double) {
        let rule = GeofenceRule(name: name, address: address, radius: radius)
        rules.append(rule)
        saveRules()
        startMonitoring(rule: rule)
    }

    func removeRule(_ rule: GeofenceRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        locationManager.stopMonitoring(identifier: rule.id)
    }

    func updateRule(_ rule: GeofenceRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
            saveRules()
            if rule.enabled { startMonitoring(rule: rule) } else { locationManager.stopMonitoring(identifier: rule.id) }
        }
    }

    private func startMonitoring(rule: GeofenceRule) {
        mapManager.geocode(rule.address) { placemark in
            guard let p = placemark else { return }
            self.locationManager.startMonitoring(placemark: p, identifier: rule.id, radius: rule.radius)
        }
    }

    private func handleRegionEvent(_ region: CLRegion) {
        guard let rule = rules.first(where: { $0.id == region.identifier && $0.enabled }) else { return }
        // schedule a local notification for this geofence trigger
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(rule.name)"
        content.body = "You're near \(rule.name)."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "geofence_\(rule.id)_\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // Persistence
    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save geofence rules:", error)
        }
    }

    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([GeofenceRule].self, from: data)
            rules = decoded
        } catch {
            print("Failed to load geofence rules:", error)
        }
    }
}

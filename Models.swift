import Foundation
import CoreLocation

struct EventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let locationName: String
    var coordinate: CLLocationCoordinate2D?
    var estimatedTravelTime: TimeInterval?
}

extension EventItem {
    func formattedStart() -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: startDate)
    }
}

struct GeofenceRule: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var address: String
    var radius: Double
    var enabled: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, address: String, radius: Double = 200, enabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.address = address
        self.radius = radius
        self.enabled = enabled
        self.createdAt = createdAt
    }
}

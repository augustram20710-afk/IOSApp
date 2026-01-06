import Foundation
import MapKit
import Combine

final class MapManager: ObservableObject {
    private let geocoder = CLGeocoder()
    private let locationProvider: LocationManager

    init(locationProvider: LocationManager) {
        self.locationProvider = locationProvider
    }

    func geocode(_ locationString: String, completion: @escaping (CLPlacemark?) -> Void) {
        // Prefer addresses in New York for this prototype: if user input doesn't include a NY hint,
        // append ", New York, NY" to increase geocoding accuracy for NYC.
        let input = locationString.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = input.lowercased()
        let tryString: String
        if lower.contains("new york") || lower.contains("ny") || lower.contains("manhattan") || lower.contains("brooklyn") {
            tryString = input
        } else {
            tryString = input + ", New York, NY"
        }

        geocoder.geocodeAddressString(tryString) { placemarks, error in
            completion(placemarks?.first)
        }
    }

    /// Estimate the best travel time among multiple transport modes. Returns a map of transport->eta and the best transport type.
    func estimateBestTravelTime(to dest: CLLocationCoordinate2D, transportModes: [MKDirectionsTransportType], completion: @escaping ([MKDirectionsTransportType: TimeInterval], MKDirectionsTransportType?) -> Void) {
        guard let fromLocation = locationProvider.currentLocation else { completion([:], nil); return }
        var results: [MKDirectionsTransportType: TimeInterval] = [:]
        let group = DispatchGroup()

        for mode in transportModes {
            group.enter()
            let request = MKDirections.Request()
            request.transportType = mode
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
            request.requestsAlternateRoutes = false
            let directions = MKDirections(request: request)
            directions.calculateETA { response, error in
                if let eta = response?.expectedTravelTime {
                    results[mode] = eta
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let best = results.min { a, b in a.value < b.value }?.key
            completion(results, best)
        }
    }

    func estimateTravelTime(to dest: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile, completion: @escaping (TimeInterval?) -> Void) {
        guard let fromLocation = locationProvider.currentLocation else { completion(nil); return }
        let request = MKDirections.Request()
        request.transportType = transportType
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        directions.calculateETA { response, error in
            guard let eta = response?.expectedTravelTime else { completion(nil); return }
            completion(eta)
        }
    }
}

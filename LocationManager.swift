import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    // publish region events so other managers can react
    let regionEvents = PassthroughSubject<CLRegion, Never>()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }

    func startSignificantMonitoring() {
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
            manager.allowsBackgroundLocationUpdates = true
        }
    }

    func startMonitoring(placemark: CLPlacemark, identifier: String, radius: CLLocationDistance = 200) {
        guard let coord = placemark.location?.coordinate else { return }
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            let region = CLCircularRegion(center: coord, radius: radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    func stopMonitoring(identifier: String) {
        for reg in manager.monitoredRegions {
            if reg.identifier == identifier, let circ = reg as? CLCircularRegion {
                manager.stopMonitoring(for: circ)
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error:", error)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region.identifier)")
        regionEvents.send(region)
    }
}

import Foundation
import Combine
import CoreLocation

enum ThemeMode: String, Codable, CaseIterable {
    case system
    case dark
}

enum TransportMode: String, Codable, CaseIterable {
    case automobile
    case walking
    case transit

    var mkType: String {
        switch self {
        case .automobile: return "automobile"
        case .walking: return "walking"
        case .transit: return "transit"
        }
    }
}

final class SettingsManager: ObservableObject {
    @Published var morningBuffer: TimeInterval
    @Published var refreshDistanceThreshold: CLLocationDistance
    @Published var transportMode: TransportMode
    @Published var arrivalBuffer: TimeInterval
    @Published var theme: ThemeMode
    @Published var arrivalBuffer: TimeInterval

    private let morningKey = "Settings.morningBuffer"
    private let refreshKey = "Settings.refreshDistanceThreshold"
    private let transportKey = "Settings.transportMode"
    private let arrivalKey = "Settings.arrivalBuffer"
    private let themeKey = "Settings.theme"

    init() {
        let defaults = UserDefaults.standard
        let mb = defaults.double(forKey: morningKey)
        self.morningBuffer = (mb > 0) ? mb : 20 * 60
        let rd = defaults.double(forKey: refreshKey)
        self.refreshDistanceThreshold = (rd > 0) ? rd : 500
        if let raw = defaults.string(forKey: transportKey), let mode = TransportMode(rawValue: raw) {
            self.transportMode = mode
        } else {
            self.transportMode = .automobile
        }
        let ab = defaults.double(forKey: arrivalKey)
        self.arrivalBuffer = (ab > 0) ? ab : 10 * 60
        if let tRaw = defaults.string(forKey: themeKey), let t = ThemeMode(rawValue: tRaw) {
            self.theme = t
        } else {
            self.theme = .dark
        }

        // persist on change
        $morningBuffer.sink { v in UserDefaults.standard.set(v, forKey: self.morningKey) }.store(in: &cancellables)
        $refreshDistanceThreshold.sink { v in UserDefaults.standard.set(v, forKey: self.refreshKey) }.store(in: &cancellables)
        $transportMode.sink { v in UserDefaults.standard.set(v.rawValue, forKey: self.transportKey) }.store(in: &cancellables)
        $arrivalBuffer.sink { v in UserDefaults.standard.set(v, forKey: self.arrivalKey) }.store(in: &cancellables)
        $theme.sink { v in UserDefaults.standard.set(v.rawValue, forKey: self.themeKey) }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}

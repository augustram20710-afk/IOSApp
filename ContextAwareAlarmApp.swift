import SwiftUI

@main
struct ContextAwareAlarmApp: App {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var mapManager = MapManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var alarmManager: AlarmManager
    @StateObject private var geofenceManager: GeofenceManager

    init() {
        let cm = CalendarManager()
        let lm = LocationManager()
        let mm = MapManager(locationProvider: lm)
        let sm = SettingsManager()
        _calendarManager = StateObject(wrappedValue: cm)
        _locationManager = StateObject(wrappedValue: lm)
        _mapManager = StateObject(wrappedValue: mm)
        let am = AlarmManager(calendar: cm, map: mm, location: lm, settings: sm)
        _alarmManager = StateObject(wrappedValue: am)
        _geofenceManager = StateObject(wrappedValue: GeofenceManager(locationManager: lm, mapManager: mm))
        _settingsManager = StateObject(wrappedValue: sm)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settingsManager.theme == .dark ? .dark : nil)
                .accentColor(.red)
                .environmentObject(calendarManager)
                .environmentObject(locationManager)
                .environmentObject(mapManager)
                .environmentObject(alarmManager)
                .environmentObject(geofenceManager)
                .environmentObject(settingsManager)
                .onAppear {
                    // Global UINavigationBar appearance for red-on-black theme
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor.black
                    appearance.titleTextAttributes = [.foregroundColor: UIColor.systemRed]
                    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.systemRed]
                    UINavigationBar.appearance().standardAppearance = appearance
                    UINavigationBar.appearance().scrollEdgeAppearance = appearance

                    calendarManager.requestAccessIfNeeded()
                    locationManager.requestAuthorization()
                    alarmManager.requestNotificationAuthorization()
                    // start background ETA refresh scheduling
                    alarmManager.scheduleAppRefresh(earliest: 60 * 30) // first refresh in 30 minutes
                    // start significant location change monitoring to trigger ETA recalculations
                    locationManager.startSignificantMonitoring()
                }
        }
    }
}

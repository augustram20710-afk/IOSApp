import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var calendar: CalendarManager
    @EnvironmentObject var mapManager: MapManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var geofenceManager: GeofenceManager

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                Section(header: Text("Today")) {
                    ForEach(calendar.events) { event in
                        EventRow(event: event)
                            .onAppear {
                                guard !event.locationName.isEmpty else { return }
                                mapManager.geocode(event.locationName) { place in
                                    guard let place = place, let coord = place.location?.coordinate else { return }
                                    // Estimate travel time
                                    let transport: MKDirectionsTransportType = {
                                        switch settings.transportMode {
                                        case .automobile: return .automobile
                                        case .walking: return .walking
                                        case .transit: return .transit
                                        }
                                    }()
                                    mapManager.estimateTravelTime(to: coord, transportType: transport) { eta in
                                        DispatchQueue.main.async {
                                            if let idx = calendar.events.firstIndex(of: event) {
                                                calendar.events[idx].coordinate = coord
                                                calendar.events[idx].estimatedTravelTime = eta
                                                // schedule alarm for this event
                                                alarmManager.scheduleAlarm(for: calendar.events[idx])
                                            }
                                            // start geofence example
                                            if let placemark = place as? CLPlacemark {
                                                locationManager.startMonitoring(placemark: placemark, identifier: event.id)
                                            }
                                        }
                                    }
                                }
                            }
                    }
                }
                Section(header: Text("Rules")) {
                    NavigationLink(destination: GeofenceRulesView()) {
                        Text("Geofence Rules")
                    }
                }
                Section(header: Text("Alarms")) {
                    NavigationLink(destination: AlarmsView()) { Text("Manage Alarms") }
                }
                Section(header: Text("Preferences")) {
                    NavigationLink(destination: SettingsView()) { Text("Settings") }
                }
                Section {
                    NavigationLink(destination: AddEventView()) {
                        HStack {
                            Spacer()
                            Text("Add Event").bold().foregroundColor(.red)
                            Spacer()
                                EventRow(event: event)
                                    .listRowBackground(Color.black)
                    }
                }
                }
                .listStyle(InsetGroupedListStyle())
                .accentColor(.red)
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Context Alarm")
            Text("Map preview")
                .font(.subheadline)
                .foregroundColor(.red)
        }
    }
}

struct EventRow: View {
    var event: EventItem
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title).font(.headline).foregroundColor(.white)
                Text(event.locationName).font(.caption).foregroundColor(Color(white: 0.8))
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(event.formattedStart())
                    .font(.subheadline)
                    .foregroundColor(.red)
                if let travel = event.estimatedTravelTime {
                    Text("Travel: \(Int(travel/60)) min")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.black)
    }
}

#if DEBUG
import PlaygroundSupport
struct Preview: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CalendarManager())
            .environmentObject(LocationManager())
            .environmentObject(MapManager(locationProvider: LocationManager()))
            .environmentObject(AlarmManager(calendar: CalendarManager(), map: MapManager(locationProvider: LocationManager()), location: LocationManager(), settings: SettingsManager()))
            .environmentObject(SettingsManager())
    }
}
#endif

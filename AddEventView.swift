import SwiftUI
import MapKit

struct AddEventView: View {
    @Environment(".presentationMode") var presentationMode
    @EnvironmentObject var calendar: CalendarManager
    @EnvironmentObject var mapManager: MapManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var settings: SettingsManager

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var locationText: String = ""
    @State private var transportOptions: [TransportMode: Bool] = [.automobile: true, .walking: false, .transit: false]
    @State private var creating = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event")) {
                    TextField("Title", text: $title)
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Location (address)", text: $locationText)
                }

                Section(header: Text("Transport (choose one or more)")) {
                    ForEach(TransportMode.allCases, id: \ .self) { mode in
                        Toggle(isOn: Binding(get: { transportOptions[mode] ?? false }, set: { transportOptions[mode] = $0 })) {
                            Text(mode.rawValue.capitalized)
                        }
                    }
                }

                Section {
                    Button(action: createEvent) {
                        HStack {
                            Spacer()
                            if creating { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .red)) }
                            Label("Create Event", systemImage: "plus.circle.fill")
                                .labelStyle(TitleOnlyLabelStyle())
                                .foregroundColor(.red)
                                .bold()
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.black)
                }
            }
            .navigationTitle("Add Event")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } } }
            .background(Color.black)
            .onAppear { UITableView.appearance().backgroundColor = UIColor.black }
        }
    }

    func createEvent() {
        guard !title.isEmpty, !locationText.isEmpty else { return }
        creating = true
        // add local event to list immediately
        calendar.addLocalEvent(title: title, startDate: date, locationName: locationText)

        // Geocode and estimate ETA using selected transport modes
        mapManager.geocode(locationText) { placemark in
            guard let p = placemark, let coord = p.location?.coordinate else {
                creating = false
                presentationMode.wrappedValue.dismiss()
                return
            }

            // build selected transport types
            let selected = transportOptions.compactMap { (k, v) -> MKDirectionsTransportType? in v ? mapTransport(k) : nil }
            let modes = selected.isEmpty ? [.automobile] : selected

            mapManager.estimateBestTravelTime(to: coord, transportModes: modes) { results, best in
                // create EventItem and schedule alarms using best ETA and arrival buffer
                DispatchQueue.main.async {
                    // find our event in calendar (by title+date) to update coordinate/eta
                    if let idx = calendar.events.firstIndex(where: { $0.title == title && Calendar.current.isDate($0.startDate, inSameDayAs: date) && $0.startDate == date }) {
                        calendar.events[idx].coordinate = coord
                        // fallback ETA if none available (assume 30 minutes)
                        let eta = best.flatMap { results[$0] } ?? (30 * 60)
                        calendar.events[idx].estimatedTravelTime = eta
                        // compute arrival buffer from settings
                        let arrival = settings.arrivalBuffer
                        // schedule wake and leave alarms using AlarmManager (it computes wake using morningBuffer)
                        alarmManager.scheduleAlarm(for: calendar.events[idx])
                        // additionally schedule an 'arrive-early' notification at startDate - arrival
                        if let eta = eta {
                            let arriveEarlyDate = calendar.events[idx].startDate.addingTimeInterval(-arrival)
                            alarmManager.scheduleCustomNotification(id: "arrive_\(calendar.events[idx].id)", title: "Arrive Early: \(calendar.events[idx].title)", body: "Aim to arrive by \(calendar.events[idx].formattedStart()) (early).", at: arriveEarlyDate)
                        }
                    }
                    creating = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    func mapTransport(_ t: TransportMode) -> MKDirectionsTransportType {
        switch t {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
}

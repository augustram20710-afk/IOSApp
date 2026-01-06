import SwiftUI
import UserNotifications

struct AlarmsView: View {
    @EnvironmentObject var calendar: CalendarManager
    @EnvironmentObject var alarmManager: AlarmManager
    @State private var pendingMap: [String: [Date]] = [:]
    @State private var loading = false

    var body: some View {
        List {
            ForEach(calendar.events) { event in
                VStack(alignment: .leading) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(event.title).font(.headline)
                            Text(event.locationName).font(.caption)
                        }
                        Spacer()
                        Text(event.formattedStart()).font(.subheadline)
                    }
                    if let dates = pendingMap[event.id], !dates.isEmpty {
                        ForEach(dates, id: \ .self) { d in
                            HStack {
                                Image(systemName: "bell.fill").foregroundColor(.red)
                                Text("Alarm: \(formatted(d))").font(.caption).foregroundColor(.gray)
                            }
                        }
                    } else {
                        Text("No scheduled alarms").font(.caption).foregroundColor(.gray)
                    }
                    HStack {
                        Button(action: {
                            alarmManager.cancelNotifications(forEventID: event.id)
                            pendingMap[event.id] = []
                        }) {
                            Label("Cancel", systemImage: "xmark.circle")
                                .labelStyle(TitleOnlyLabelStyle())
                                .foregroundColor(.red)
                        }
                        Spacer()
                        Button(action: {
                            loading = true
                            alarmManager.rescheduleAlarm(for: event) { success in
                                reloadPending(for: event)
                                loading = false
                            }
                        }) {
                            Label("Reschedule", systemImage: "arrow.triangle.2.circlepath")
                                .labelStyle(TitleOnlyLabelStyle())
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.black)
            }
        }
        .navigationTitle("Alarms")
        .onAppear(perform: loadAllPending)
    }

    func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .short
        return f.string(from: d)
    }

    func loadAllPending() {
        pendingMap = [:]
        for ev in calendar.events {
            reloadPending(for: ev)
        }
    }

    func reloadPending(for ev: EventItem) {
        alarmManager.pendingNotifications(forEventID: ev.id) { requests in
            let dates = requests.compactMap { $0.trigger?.nextTriggerDate() }
            DispatchQueue.main.async {
                pendingMap[ev.id] = dates.sorted()
            }
        }
    }
}

#if DEBUG
struct AlarmsView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmsView()
            .environmentObject(CalendarManager())
            .environmentObject(AlarmManager(calendar: CalendarManager(), map: MapManager(locationProvider: LocationManager()), location: LocationManager(), settings: SettingsManager()))
            .environmentObject(SettingsManager())
    }
}
#endif

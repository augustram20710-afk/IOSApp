import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var morningMinutes: String = ""
    @State private var refreshMeters: String = ""

    var body: some View {
        Form {
            Section(header: Text("Morning")) {
                HStack {
                    Text("Prep time")
                    Spacer()
                    TextField("Minutes", text: $morningMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
            }

            Section(header: Text("Location / Refresh")) {
                HStack {
                    Text("Refresh distance (m)")
                    Spacer()
                    TextField("Meters", text: $refreshMeters)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
            }

            Section(header: Text("Arrival")) {
                HStack {
                    Text("Arrive early (min)")
                    Spacer()
                    TextField("Minutes", text: Binding(get: { String(Int(settings.arrivalBuffer / 60)) }, set: { settings.arrivalBuffer = Double($0) ?? settings.arrivalBuffer }))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
            }

            Section(header: Text("Transport")) {
                Picker("Mode", selection: $settings.transportMode) {
                    ForEach(TransportMode.allCases, id: \ .self) { m in
                        Text(m.rawValue.capitalized).tag(m)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            morningMinutes = String(Int(settings.morningBuffer / 60))
            refreshMeters = String(Int(settings.refreshDistanceThreshold))
        }
        .onDisappear {
            if let mins = Double(morningMinutes) { settings.morningBuffer = mins * 60 }
            if let meters = Double(refreshMeters) { settings.refreshDistanceThreshold = meters }
        }
        .foregroundColor(.white)
        .background(Color.black)
        .listStyle(InsetGroupedListStyle())
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(SettingsManager())
    }
}
#endif

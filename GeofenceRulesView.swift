import SwiftUI

struct GeofenceRulesView: View {
    @EnvironmentObject var geofenceManager: GeofenceManager
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(geofenceManager.rules) { rule in
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text(rule.name).font(.headline).foregroundColor(.white)
                        Text(rule.address).font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Text("\(Int(rule.radius)) m").font(.caption).foregroundColor(.gray)
                }
                .listRowBackground(Color.black)
            }
            .onDelete { idx in
                for i in idx { let r = geofenceManager.rules[i]; geofenceManager.removeRule(r) }
            }
        }
        .navigationTitle("Geofence Rules")
        .toolbar { Button("Add") { showingAdd = true } }
        .sheet(isPresented: $showingAdd) {
            AddGeofenceSheet(isPresented: $showingAdd)
                .environmentObject(geofenceManager)
        }
    }
}

struct AddGeofenceSheet: View {
    @EnvironmentObject var geofenceManager: GeofenceManager
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var address = ""
    @State private var radius = "200"

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                TextField("Address", text: $address)
                TextField("Radius (meters)", text: $radius)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Add Rule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let r = Double(radius) ?? 200
                        geofenceManager.addRule(name: name, address: address, radius: r)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
            }
        }
    }
}

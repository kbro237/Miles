import SwiftUI

#if os(macOS)
struct ContentView: View {
    @State private var selectedSection: String? = "trips"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("Trips", systemImage: "car").tag("trips")
                Label("Quarters", systemImage: "calendar").tag("quarters")
                Divider()
                Label("Settings", systemImage: "gear").tag("settings")
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedSection {
            case "trips": TripListView()
            case "quarters": QuarterListView()
            case "settings": SettingsView()
            default: Color.clear
            }
        }
    }
}
#else
struct ContentView: View {
    var body: some View {
        TabView {
            TripListView()
                .tabItem { Label("Trips", systemImage: "car") }

            QuarterListView()
                .tabItem { Label("Quarters", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
#endif

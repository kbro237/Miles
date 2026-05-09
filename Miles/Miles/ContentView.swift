import SwiftUI

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

import SwiftUI
import SwiftData

@main
struct MilesApp: App {
    let container: ModelContainer = {
        let schema = Schema([Trip.self, FrequentDestination.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
#if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Trip") {
                    NotificationCenter.default.post(name: .init("newTrip"), object: nil)
                }
                .keyboardShortcut("n")
            }
        }
#endif
    }
}

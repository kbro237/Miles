import SwiftUI
import SwiftData

@main
struct MilesApp: App {
    let container: ModelContainer = {
        let schema = Schema([Trip.self, FrequentDestination.self, PaidQuarter.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            migratePaidQuarters(context: container.mainContext)
            return container
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

    private static func migratePaidQuarters(context: ModelContext) {
        let migratedKey = "paidQuartersMigrated"
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        let paidIDs = UserDefaults.standard.stringArray(forKey: "paidQuarters") ?? []
        for id in paidIDs {
            context.insert(PaidQuarter(quarterID: id))
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: migratedKey)
    }
}

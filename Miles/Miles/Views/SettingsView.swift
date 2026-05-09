import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var destinations: [FrequentDestination]
    @Query private var trips: [Trip]

    @State private var currentRate: Int = IRSRateService.currentYearDefaultRate
    @State private var isCheckingRate = false
    @State private var showingDestinations = false
    @State private var showingImporter = false
    @State private var showingImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @AppStorage("defaultOrigin") private var defaultOrigin: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("IRS Mileage Rate") {
                    HStack {
                        Text("Current Rate")
                        Spacer()
                        Text("\(currentRate)¢/mile")
                            .foregroundStyle(.secondary)
                    }

                    Button("Check Current Rate") {
                        Task { await checkRate() }
                    }
                    .disabled(isCheckingRate)

                    if isCheckingRate {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Looking up...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Defaults") {
                    TextField("Default Origin Address", text: $defaultOrigin, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Frequent Destinations") {
                    ForEach(destinations) { dest in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dest.name)
                                .font(.body)
                            Text(dest.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            context.delete(destinations[index])
                        }
                    }

                    Button("Manage Destinations") {
                        showingDestinations = true
                    }
                }

                Section("Backup & Restore") {
                    Button("Export Database") {
                        exportDatabase()
                    }

                    Button("Import Database") {
                        showingImporter = true
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Miles Mileage Tracker")
                    LabeledContent("Trips", value: "\(trips.count)")
                    LabeledContent("Destinations", value: "\(destinations.count)")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDestinations) {
                FrequentDestinationListView()
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Database", isPresented: $showingImportConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Import", role: .destructive) {
                    performImport()
                }
            } message: {
                Text("This will replace all existing trips and destinations with the imported data.")
            }
            .alert("Database", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Task { await checkRate() }
            }
        }
    }

    private func checkRate() async {
        isCheckingRate = true
        let rate = await IRSRateService.fetchCurrentRate()
        currentRate = rate
        isCheckingRate = false
    }

    private func exportDatabase() {
        guard let data = DatabaseExportService.exportData(trips: trips, destinations: destinations) else {
            alertMessage = "Failed to export database."
            showingAlert = true
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Miles-backup.json")
        try? data.write(to: url)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(av, animated: true)
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let data = try? Data(contentsOf: url) else {
                alertMessage = "Could not read the selected file."
                showingAlert = true
                return
            }
            pendingImportData = data
            showingImportConfirm = true
        case .failure:
            alertMessage = "Could not open the selected file."
            showingAlert = true
        }
    }

    private func performImport() {
        guard let data = pendingImportData else { return }
        do {
            try DatabaseExportService.importData(
                from: data,
                existingTrips: trips,
                existingDestinations: destinations,
                context: context
            )
            alertMessage = "Database imported successfully."
        } catch {
            alertMessage = "Failed to import: \(error.localizedDescription)"
        }
        showingAlert = true
        pendingImportData = nil
    }
}

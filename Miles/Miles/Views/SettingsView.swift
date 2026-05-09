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

                Section("Frequent Destinations") {
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
            guard let url = urls.first else {
                alertMessage = "No file selected."
                showingAlert = true
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Could not access the selected file."
                showingAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                pendingImportData = data
                showingImportConfirm = true
            } catch {
                alertMessage = "Could not read the selected file: \(error.localizedDescription)"
                showingAlert = true
            }
        case .failure(let error):
            alertMessage = "Could not open file: \(error.localizedDescription)"
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

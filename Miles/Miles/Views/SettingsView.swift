import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var destinations: [FrequentDestination]
    @Query private var trips: [Trip]
    @Query private var paidQuarters: [PaidQuarter]

    @State private var isCheckingRate = false
    @State private var rateText: String = ""
    @State private var showingDestinations = false
    @FocusState private var rateFieldFocused: Bool
    @State private var syncToken: String = SyncService.storedToken
    @State private var syncEndpoint: String = SyncService.storedEndpoint
    @State private var isSyncing = false
    @State private var syncMessage = ""
    @State private var showingImporter = false
    @State private var showingImportConfirm = false
    @State private var pendingImportData: Data?
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
#if os(macOS)
        Form {
            content
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingDestinations) {
            FrequentDestinationListView()
#if os(macOS)
                .frame(minWidth: 450, minHeight: 350)
#endif
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
            refreshRateDisplay()
        }
#else
        NavigationStack {
            Form {
                content
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
                refreshRateDisplay()
            }
            .toolbar {
                if rateFieldFocused {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            rateFieldFocused = false
                        }
                    }
                }
            }
        }
#endif
    }

    @ViewBuilder
    private var content: some View {
        Section("IRS Mileage Rate") {
                    HStack {
                        Text("Rate")
                        TextField("", text: $rateText)
                            .frame(width: 60)
#if os(iOS)
                            .keyboardType(.decimalPad)
                            .focused($rateFieldFocused)
#endif
                            .onChange(of: rateText) { _, newValue in
                                let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                                if let value = Double(cleaned), value > 0 {
                                    IRSRateService.manualOverride = value
                                }
                            }
                        Text("¢/mile")
                            .foregroundStyle(.secondary)
                    }
                    if IRSRateService.isManual {
                        Text("Using manual rate")
                            .font(.caption)
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

                Section("Sync") {
                    TextField("Token", text: $syncToken)
                        .font(.system(.caption, design: .monospaced))
                    TextField("Endpoint URL", text: $syncEndpoint)
                        .font(.system(.caption, design: .monospaced))
#if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
#endif
                    if !syncToken.isEmpty && !syncEndpoint.isEmpty {
                        Button("Save Sync Config") {
                            SyncService.configure(token: syncToken, endpoint: syncEndpoint)
                            syncMessage = "Config saved."
                        }
                    }

                    if SyncService.isConfigured {
                        if !syncMessage.isEmpty {
                            Text(syncMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button("Pull from Server") {
                                Task { await performPull() }
                            }
                            .disabled(isSyncing)

                            Button("Push to Server") {
                                Task { await performPush() }
                            }
                            .disabled(isSyncing)
                        }

                        if isSyncing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button("Clear Sync Config") {
                            SyncService.clearConfig()
                            syncToken = ""
                            syncEndpoint = ""
                            syncMessage = ""
                        }
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Miles Mileage Tracker")
                    LabeledContent("Trips", value: "\(trips.count)")
                    LabeledContent("Destinations", value: "\(destinations.count)")
                }
    }

    private func performPull() async {
        isSyncing = true
        syncMessage = ""
        let service = SyncService()
        guard let provider = service.makeProvider() else {
            syncMessage = "Sync not configured."
            isSyncing = false
            return
        }
        do {
            let changed = try await service.pull(
                provider: provider,
                trips: trips,
                destinations: destinations,
                paidQuarters: paidQuarters,
                context: context
            )
            syncMessage = changed ? "Data pulled from server." : "No new data."
        } catch {
            syncMessage = "Pull failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    private func performPush() async {
        isSyncing = true
        syncMessage = ""
        let service = SyncService()
        guard let provider = service.makeProvider() else {
            syncMessage = "Sync not configured."
            isSyncing = false
            return
        }
        do {
            try await service.push(
                provider: provider,
                trips: trips,
                destinations: destinations,
                paidQuarters: paidQuarters
            )
            syncMessage = "Data pushed to server."
        } catch {
            syncMessage = "Push failed: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    private func checkRate() async {
        isCheckingRate = true
        IRSRateService.manualOverride = 0.0
        _ = await IRSRateService.fetchCurrentRate()
        rateText = ""
        isCheckingRate = false
    }

    private func refreshRateDisplay() {
        rateText = IRSRateService.isManual ? String(format: "%.1f", IRSRateService.manualOverride) : ""
    }

    private func exportDatabase() {
        guard let data = DatabaseExportService.exportData(trips: trips, destinations: destinations, paidQuarters: paidQuarters) else {
            alertMessage = "Failed to export database."
            showingAlert = true
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Miles-backup.json")
        do {
            try data.write(to: url)
        } catch {
            alertMessage = "Failed to write export file."
            showingAlert = true
            return
        }
#if os(macOS)
        guard let contentView = NSApp.keyWindow?.contentView else { return }
        NSSharingServicePicker(items: [url])
            .show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
#else
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(av, animated: true)
#endif
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
        if let backup = DatabaseExportService.exportData(trips: trips, destinations: destinations, paidQuarters: paidQuarters) {
            let backupURL = FileManager.default.temporaryDirectory.appendingPathComponent("Miles-pre-import-backup.json")
            try? backup.write(to: backupURL)
        }
        do {
            try DatabaseExportService.importData(
                from: data,
                existingTrips: trips,
                existingDestinations: destinations,
                existingPaidQuarters: paidQuarters,
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

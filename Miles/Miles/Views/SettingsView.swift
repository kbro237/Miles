import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var destinations: [FrequentDestination]

    @State private var currentRate: Int = IRSRateService.currentYearDefaultRate
    @State private var isCheckingRate = false
    @State private var showingDestinations = false
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

                Section("About") {
                    LabeledContent("App", value: "Miles Mileage Tracker")
                    LabeledContent("Data", value: "\(destinations.count) destinations")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDestinations) {
                FrequentDestinationListView()
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
}

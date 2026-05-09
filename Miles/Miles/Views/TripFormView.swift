import SwiftUI
import SwiftData
import MapKit

struct TripFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var purpose: String = ""
    @State private var originAddress: String = ""
    @State private var destinationAddress: String = ""
    @State private var isRoundTrip: Bool = false
    @State private var distanceMiles: String = ""
    @State private var rateCents: Int = IRSRateService.currentYearDefaultRate
    @State private var notes: String = ""
    @State private var selectedDestination: FrequentDestination?

    @State private var isCalculating = false
    @State private var showSuggestions = false
    @State private var suggestionField: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""

    @Query private var destinations: [FrequentDestination]

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Purpose", text: $purpose)
                }

                Section("Route") {
                    AutocompleteAddressField(
                        label: "Origin",
                        text: $originAddress,
                        destinations: destinations,
                        isActive: $showSuggestions,
                        field: $suggestionField,
                        fieldId: "origin"
                    )

                    AutocompleteAddressField(
                        label: "Destination",
                        text: $destinationAddress,
                        destinations: destinations,
                        isActive: $showSuggestions,
                        field: $suggestionField,
                        fieldId: "destination"
                    )

                    Toggle("Round Trip", isOn: $isRoundTrip)

                    HStack {
                        TextField("Distance (miles)", text: $distanceMiles)
                            .keyboardType(.decimalPad)

                        if isCalculating {
                            ProgressView()
                                .padding(.leading, 4)
                        }

                        Button("Calculate") {
                            Task { await calculateDistance() }
                        }
                        .disabled(originAddress.isEmpty || destinationAddress.isEmpty)
                    }
                }

                Section("Reimbursement") {
                    HStack {
                        Text("Rate")
                        Spacer()
                        Text("\(rateCents)¢/mile")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTrip() }
                        .disabled(purpose.isEmpty || distanceMiles.isEmpty || Double(distanceMiles) == nil)
                }
            }
            .alert("", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                rateCents = IRSRateService.currentYearDefaultRate
                Task {
                    let fetched = await IRSRateService.fetchCurrentRate()
                    rateCents = fetched
                }
            }
        }
    }

    private func calculateDistance() async {
        guard !originAddress.isEmpty, !destinationAddress.isEmpty else { return }
        isCalculating = true
        do {
            let miles = try await DistanceCalculator.calculate(origin: originAddress, destination: destinationAddress)
            distanceMiles = String(format: "%.1f", miles)
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        isCalculating = false
    }

    private func saveTrip() {
        guard let miles = Double(distanceMiles) else { return }
        let trip = Trip(
            date: date,
            purpose: purpose,
            distanceMiles: miles,
            isRoundTrip: isRoundTrip,
            rateCentsPerMile: rateCents,
            originAddress: originAddress,
            destinationAddress: destinationAddress,
            notes: notes.isEmpty ? nil : notes,
            destination: selectedDestination
        )
        context.insert(trip)
        dismiss()
    }
}

struct AutocompleteAddressField: View {
    let label: String
    @Binding var text: String
    let destinations: [FrequentDestination]
    @Binding var isActive: Bool
    @Binding var field: String?
    let fieldId: String

    @State private var searchService = AddressSearchService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(label, text: $text)
                .onChange(of: text) { _, newValue in
                    if !newValue.isEmpty {
                        isActive = true
                        field = fieldId
                    }
                    searchService.search(newValue)
                }
                .onTapGesture {
                    isActive = true
                    field = fieldId
                }

            if isActive && field == fieldId && !text.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    let matches = destinations.filter {
                        $0.name.localizedCaseInsensitiveContains(text) ||
                        $0.address.localizedCaseInsensitiveContains(text)
                    }

                    ForEach(matches) { dest in
                        Button(action: {
                            text = dest.address
                            isActive = false
                            field = nil
                            searchService.results = []
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dest.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(dest.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }

                    ForEach(searchService.results, id: \.self) { completion in
                        Button(action: {
                            text = "\(completion.title), \(completion.subtitle)"
                            isActive = false
                            field = nil
                            searchService.results = []
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .cornerRadius(8)
            }
        }
    }
}

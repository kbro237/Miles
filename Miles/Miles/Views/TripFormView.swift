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
                        .disabled(purpose.isEmpty || !isValidDistance)
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

    private var isValidDistance: Bool {
        guard let value = Double(distanceMiles) else { return false }
        return value > 0
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
    @State private var didSelect = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(label, text: $text)
                .onChange(of: text) { _, newValue in
                    guard !didSelect else {
                        didSelect = false
                        return
                    }
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
                            didSelect = true
                            isActive = false
                            field = nil
                            searchService.results = []
                            text = dest.address
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dest.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(dest.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }

                    ForEach(searchService.results, id: \.self) { completion in
                        Button(action: {
                            didSelect = true
                            isActive = false
                            field = nil
                            searchService.results = []
                            text = "\(completion.title), \(completion.subtitle)"
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .padding(.top, 4)
            }
        }
    }
}

import SwiftUI
import SwiftData
import MapKit

struct TripFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editing: Trip?

    @State private var date: Date = .now
    @State private var purpose: String = ""
    @State private var originAddress: String = ""
    @State private var destinationAddress: String = ""
    @State private var isRoundTrip: Bool = false
    @State private var distanceMiles: String = ""
    @State private var rateCents: Double = IRSRateService.currentDefaultRate
    @State private var notes: String = ""
    @State private var selectedDestination: FrequentDestination?

    @State private var isCalculating = false
    @State private var showSuggestions = false
    @State private var suggestionField: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""

    @Query private var destinations: [FrequentDestination]
    @AppStorage("defaultOrigin") private var defaultOrigin: String = ""

    private var isEditing: Bool { editing != nil }

    var body: some View {
#if os(macOS)
        Form {
            content
        }
        .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
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
            populateFields()
        }
#else
        NavigationStack {
            Form {
                content
            }
            .navigationTitle(isEditing ? "Edit Trip" : "New Trip")
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
                populateFields()
            }
        }
#endif
    }

    @ViewBuilder
    private var content: some View {
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
                        fieldId: "destination",
                        onSelectDestination: { selectedDestination = $0 }
                    )

                    Toggle("Round Trip", isOn: $isRoundTrip)

                    HStack {
                        TextField("Distance (miles)", text: $distanceMiles)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif

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
                        Text("\(String(format: "%.1f", rateCents))¢/mile")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }

    private func populateFields() {
        if let trip = editing {
            date = trip.date
            purpose = trip.purpose
            originAddress = trip.originAddress
            destinationAddress = trip.destinationAddress
            isRoundTrip = trip.isRoundTrip
            distanceMiles = String(format: "%.1f", trip.distanceMiles)
            rateCents = trip.rateCentsPerMile
            notes = trip.notes ?? ""
            selectedDestination = trip.destination
        } else {
            rateCents = IRSRateService.currentDefaultRate
            Task {
                let fetched = await IRSRateService.fetchCurrentRate()
                rateCents = fetched
            }
            if !defaultOrigin.isEmpty && originAddress.isEmpty {
                originAddress = defaultOrigin
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

        if let trip = editing {
            trip.date = date
            trip.purpose = purpose
            trip.distanceMiles = miles
            trip.isRoundTrip = isRoundTrip
            trip.rateCentsPerMile = rateCents
            trip.originAddress = originAddress
            trip.destinationAddress = destinationAddress
            trip.notes = notes.isEmpty ? nil : notes
            trip.destination = selectedDestination
        } else {
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
        }
        do {
            try context.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save trip: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct AutocompleteAddressField: View {
    let label: String
    @Binding var text: String
    let destinations: [FrequentDestination]
    @Binding var isActive: Bool
    @Binding var field: String?
    let fieldId: String
    var onSelectDestination: ((FrequentDestination) -> Void)?

    @State private var searchService = AddressSearchService()
    @State private var didSelect = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(label, text: $text)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    guard !didSelect else {
                        didSelect = false
                        return
                    }
                    if isFocused && !newValue.isEmpty {
                        isActive = true
                        field = fieldId
                    }
                    if isFocused {
                        searchService.search(newValue)
                    }
                }
                .onTapGesture {
                    isActive = true
                    field = fieldId
                    if !text.isEmpty {
                        searchService.search(text)
                    }
                }
                .overlay(alignment: .trailing) {
                    if !text.isEmpty {
                        Button {
                            didSelect = true
                            isActive = false
                            field = nil
                            searchService.results = []
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 2)
                    }
                }

            if isActive && field == fieldId && !text.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    let matches = destinations.filter {
                        $0.name.localizedCaseInsensitiveContains(text) ||
                        $0.address.localizedCaseInsensitiveContains(text)
                    }

                    ForEach(matches) { dest in
                        Button(action: {
                            onSelectDestination?(dest)
                            didSelect = true
                            isActive = false
                            field = nil
                            searchService.results = []
                            isFocused = false
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
                            isFocused = false
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
#if os(iOS)
                .background(Color(.systemBackground))
#else
                .background(Color(nsColor: .windowBackgroundColor))
#endif
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
#if os(iOS)
                        .stroke(Color(.separator), lineWidth: 1)
#else
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
#endif
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .padding(.top, 4)
            }
        }
    }
}

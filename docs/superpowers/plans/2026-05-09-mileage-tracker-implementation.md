# Miles Mileage Tracker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal iOS mileage tracking app with SwiftUI + SwiftData, MapKit distance calculation, quarterly grouping, and CSV/Markdown/PDF export.

**Architecture:** MVVM with SwiftData persistence. Three-tab layout (Trips / Quarters / Settings). MapKit `MKDirections` for distance, `UIActivityViewController` for export sharing. IRS rate stored per-trip, looked up on launch.

**Tech Stack:** SwiftUI, SwiftData (iOS 17+), MapKit, no external dependencies.

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Miles/MilesApp.swift`
- Create: `Miles/ContentView.swift`

- [ ] **Step 1: Create MilesApp.swift**

```swift
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
    }
}
```

- [ ] **Step 2: Create ContentView.swift**

```swift
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
```

- [ ] **Step 3: Add empty placeholder views so the project compiles**

Create empty stubs for `TripListView`, `QuarterListView`, `SettingsView`:

```swift
// Each in its own file under Views/
struct TripListView: View {
    var body: some View { Text("Trips") }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: initial project scaffolding with 3-tab layout"
```

---

### Task 2: Data Models

**Files:**
- Create: `Miles/Models/Trip.swift`
- Create: `Miles/Models/FrequentDestination.swift`
- Create: `Miles/Models/Quarter.swift`

- [ ] **Step 1: Create Trip model**

```swift
import Foundation
import SwiftData

@Model
final class Trip {
    var date: Date
    var purpose: String
    var distanceMiles: Double
    var isRoundTrip: Bool
    var rateCentsPerMile: Int
    var originAddress: String
    var destinationAddress: String
    var notes: String?
    var destination: FrequentDestination?

    init(
        date: Date = .now,
        purpose: String = "",
        distanceMiles: Double = 0,
        isRoundTrip: Bool = false,
        rateCentsPerMile: Int = 0,
        originAddress: String = "",
        destinationAddress: String = "",
        notes: String? = nil,
        destination: FrequentDestination? = nil
    ) {
        self.date = date
        self.purpose = purpose
        self.distanceMiles = distanceMiles
        self.isRoundTrip = isRoundTrip
        self.rateCentsPerMile = rateCentsPerMile
        self.originAddress = originAddress
        self.destinationAddress = destinationAddress
        self.notes = notes
        self.destination = destination
    }

    var reimbursementDollars: Double {
        let miles = distanceMiles.roundedTo1dp
        let rate = Double(rateCentsPerMile) / 100.0
        return (miles * rate).roundedTo2dp
    }

    var effectiveDistance: Double {
        isRoundTrip ? distanceMiles * 2 : distanceMiles
    }

    var effectiveDistanceRounded: Double {
        effectiveDistance.roundedTo1dp
    }

    var reimbursementTotal: Double {
        let miles = effectiveDistanceRounded
        let rate = Double(rateCentsPerMile) / 100.0
        return (miles * rate).roundedTo2dp
    }
}
```

- [ ] **Step 2: Create FrequentDestination model**

```swift
import Foundation
import SwiftData

@Model
final class FrequentDestination {
    @Attribute(.unique) var name: String
    var address: String

    init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}
```

- [ ] **Step 3: Create Quarter model**

```swift
import Foundation

struct Quarter: Identifiable, Equatable {
    let year: Int
    let quarterNumber: Int
    var id: String { "\(year)-Q\(quarterNumber)" }

    var displayString: String { "Q\(quarterNumber) \(year)" }

    var startDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = (quarterNumber - 1) * 3 + 1
        components.day = 1
        return Calendar.current.date(from: components) ?? .now
    }

    var endDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = quarterNumber * 3
        components.day = Calendar.current.range(of: .day, in: .month, for: startDate)?.upperBound ?? 30
        return Calendar.current.date(from: components) ?? .now
    }

    static func current() -> Quarter {
        let now = Date()
        let month = Calendar.current.component(.month, from: now)
        let year = Calendar.current.component(.year, from: now)
        return Quarter(year: year, quarterNumber: (month - 1) / 3 + 1)
    }

    static func allQuarters(for trips: [Trip]) -> [Quarter] {
        let calendar = Calendar.current
        let dateSet = Set(trips.map { trip -> String in
            let month = calendar.component(.month, from: trip.date)
            let year = calendar.component(.year, from: trip.date)
            let q = (month - 1) / 3 + 1
            return "\(year)-Q\(q)"
        })
        return dateSet.compactMap { id -> Quarter? in
            let parts = id.split(separator: "-Q")
            guard parts.count == 2, let year = Int(parts[0]), let q = Int(parts[1]) else { return nil }
            return Quarter(year: year, quarterNumber: q)
        }.sorted { $0.id > $1.id }
    }

    func trips(from allTrips: [Trip]) -> [Trip] {
        let calendar = Calendar.current
        return allTrips.filter { trip in
            let month = calendar.component(.month, from: trip.date)
            let year = calendar.component(.year, from: trip.date)
            let q = (month - 1) / 3 + 1
            return q == quarterNumber && year == self.year
        }
    }

    func totalMiles(for trips: [Trip]) -> Double {
        trips.reduce(0) { $0 + $1.effectiveDistanceRounded }
    }

    func totalReimbursement(for trips: [Trip]) -> Double {
        trips.reduce(0) { $0 + $1.reimbursementTotal }
    }
}
```

- [ ] **Step 4: Create Double+Extensions.swift**

```swift
import Foundation

extension Double {
    var roundedTo2dp: Double {
        (self * 100).rounded() / 100
    }

    var roundedTo1dp: Double {
        (self * 10).rounded() / 10
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add data models (Trip, FrequentDestination, Quarter) and rounding extensions"
```

---

### Task 3: Distance Calculation Service

**Files:**
- Create: `Miles/Services/DistanceCalculator.swift`

- [ ] **Step 1: Create DistanceCalculator.swift**

```swift
import MapKit

enum DistanceCalculatorError: LocalizedError {
    case noResults
    case invalidAddresses

    var errorDescription: String? {
        switch self {
        case .noResults: return "Could not calculate distance between these addresses."
        case .invalidAddresses: return "Please enter valid origin and destination addresses."
        }
    }
}

struct DistanceCalculator {

    static func calculate(origin: String, destination: String) async throws -> Double {
        let request = MKDirections.Request()
        request.transportType = .automobile

        let sourcePlacemark = try await geocode(address: origin)
        let destPlacemark = try await geocode(address: destination)

        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destPlacemark)

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw DistanceCalculatorError.noResults
        }

        return route.distance / 1609.34
    }

    private static func geocode(address: String) async throws -> MKPlacemark {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let location = placemarks.first, let clLocation = location.location else {
            throw DistanceCalculatorError.invalidAddresses
        }
        return MKPlacemark(coordinate: clLocation.coordinate)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add MapKit distance calculation service"
```

---

### Task 4: IRS Rate Service

**Files:**
- Create: `Miles/Services/IRSRateService.swift`

- [ ] **Step 1: Create IRSRateService.swift**

This fetches the current IRS mileage rate from the IRS website. Free, no API key needed.

```swift
import Foundation

struct IRSRateService {

    static let standardRateKey = "lastKnownIRSRateCents"

    static var currentYearDefaultRate: Int {
        let year = Calendar.current.component(.year, from: Date())
        return defaultRate(for: year)
    }

    static func defaultRate(for year: Int) -> Int {
        switch year {
        case 2026: return 70
        case 2025: return 70
        case 2024: return 67
        case 2023: return 65
        case 2022: return 62
        default: return 70
        }
    }

    static func fetchCurrentRate() async -> Int {
        guard let url = URL(string: "https://www.irs.gov/tax-professionals/standard-mileage-rates") else {
            return currentYearDefaultRate
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return currentYearDefaultRate
            }
            return parseRateFromHTML(html) ?? currentYearDefaultRate
        } catch {
            return currentYearDefaultRate
        }
    }

    private static func parseRateFromHTML(_ html: String) -> Int? {
        let patterns = [
            "business rate\\s*(?:for \\d{4})?\\s*(?:is|:) \\$?(\\d+)\\.?(\\d{2})?",
            "(\\d+)\\.?(\\d{2})?\\s*¢? per mile for business"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range) {
                    let dollarRange = match.range(at: 1)
                    if let swiftRange = Range(dollarRange, in: html),
                       let dollars = Int(html[swiftRange]) {
                        return dollars
                    }
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: add IRS rate service with web lookup and fallback defaults"
```

---

### Task 5: Main Trip Views

**Files:**
- Create: `Miles/Views/TripListView.swift`
- Create: `Miles/Views/TripFormView.swift`
- Create: `Miles/Views/TripDetailView.swift`

- [ ] **Step 1: Create TripListView.swift**

```swift
import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]

    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripRowView(trip: trip)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(trips[index])
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                TripFormView()
            }
        }
    }
}

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if trip.isRoundTrip {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(trip.purpose.isEmpty ? "No purpose" : trip.purpose)
                .font(.body)
            HStack(spacing: 16) {
                Label("\(trip.effectiveDistanceRounded, specifier: "%.1f") mi", systemImage: "road")
                    .font(.caption)
                Label("$\(trip.reimbursementTotal, specifier: "%.2f")", systemImage: "dollarsign")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Create TripFormView.swift (add/edit trip)**

```swift
import SwiftUI
import SwiftData

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

    @Query private var destinations: [FrequentDestination]

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

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
                        .disabled(purpose.isEmpty || distanceMiles.isEmpty)
                }
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
            distanceMiles = ""
        }
        isCalculating = false
    }

    private func saveTrip() {
        let miles = Double(distanceMiles) ?? 0
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: $text)
                .onChange(of: text) { _, newValue in
                    if !newValue.isEmpty {
                        isActive = true
                        field = fieldId
                    }
                }
                .onTapGesture {
                    isActive = true
                    field = fieldId
                }

            if isActive && field == fieldId && !text.isEmpty {
                let matches = destinations.filter {
                    $0.name.localizedCaseInsensitiveContains(text) ||
                    $0.address.localizedCaseInsensitiveContains(text)
                }
                if !matches.isEmpty {
                    ForEach(matches) { dest in
                        Button(action: {
                            text = dest.address
                            isActive = false
                            field = nil
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dest.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(dest.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create TripDetailView.swift**

```swift
import SwiftUI

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        List {
            Section("Trip Details") {
                LabeledContent("Date", value: trip.date, style: .date)
                LabeledContent("Purpose", value: trip.purpose)
                if let notes = trip.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            }

            Section("Route") {
                LabeledContent("Origin", value: trip.originAddress)
                LabeledContent("Destination", value: trip.destinationAddress)
                LabeledContent("Round Trip", value: trip.isRoundTrip ? "Yes" : "No")
                LabeledContent("Distance", value: "\(trip.distanceMiles.formatted(.number.precision(.fractionLength(1)))) mi")
                LabeledContent("Effective Distance", value: "\(trip.effectiveDistanceRounded.formatted(.number.precision(.fractionLength(1)))) mi")
            }

            Section("Reimbursement") {
                LabeledContent("Rate", value: "\(trip.rateCentsPerMile)¢/mile")
                LabeledContent("Total", value: trip.reimbursementTotal, format: .currency(code: "USD"))
            }

            if let dest = trip.destination {
                Section("Saved Destination") {
                    LabeledContent("Name", value: dest.name)
                    LabeledContent("Address", value: dest.address)
                }
            }
        }
        .navigationTitle("Trip Details")
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add trip list, form, and detail views with auto-suggest"
```

---

### Task 6: Quarter Views + Paid Status

**Files:**
- Create: `Miles/Views/QuarterListView.swift`
- Create: `Miles/Views/QuarterDetailView.swift`

- [ ] **Step 1: Create QuarterListView.swift**

```swift
import SwiftUI
import SwiftData

struct QuarterListView: View {
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]
    @State private var paidQuarters: Set<String> = UserDefaults.standard.stringArray(forKey: "paidQuarters")
        .map { Set($0) } ?? []

    var quarters: [Quarter] {
        Quarter.allQuarters(for: trips)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(quarters) { quarter in
                    NavigationLink(destination: QuarterDetailView(
                        quarter: quarter,
                        trips: quarter.trips(from: trips),
                        isPaid: Binding(
                            get: { paidQuarters.contains(quarter.id) },
                            set: { newValue in
                                if newValue {
                                    paidQuarters.insert(quarter.id)
                                } else {
                                    paidQuarters.remove(quarter.id)
                                }
                                UserDefaults.standard.set(Array(paidQuarters), forKey: "paidQuarters")
                            }
                        )
                    )) {
                        QuarterRowView(
                            quarter: quarter,
                            trips: quarter.trips(from: trips),
                            isPaid: paidQuarters.contains(quarter.id)
                        )
                    }
                }
            }
            .navigationTitle("Quarters")
        }
    }
}

struct QuarterRowView: View {
    let quarter: Quarter
    let trips: [Trip]
    let isPaid: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quarter.displayString)
                    .font(.headline)
                Text("\(trips.count) trip\(trips.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(quarter.totalMiles(for: trips).formatted(.number.precision(.fractionLength(1)))) mi")
                    .font(.subheadline)
                Text(quarter.totalReimbursement(for: trips), format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isPaid {
                    Text("Paid")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Create QuarterDetailView.swift**

```swift
import SwiftUI

struct QuarterDetailView: View {
    let quarter: Quarter
    let trips: [Trip]
    @Binding var isPaid: Bool

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Quarter", value: quarter.displayString)
                LabeledContent("Total Trips", value: "\(trips.count)")
                LabeledContent("Total Miles", value: "\(quarter.totalMiles(for: trips).formatted(.number.precision(.fractionLength(1))))")
                LabeledContent("Total Reimbursement", value: quarter.totalReimbursement(for: trips), format: .currency(code: "USD"))

                Toggle("Paid", isOn: $isPaid)
            }

            Section("Export") {
                Button("Export as CSV") { shareCSV() }
                Button("Export as Markdown") { shareMarkdown() }
                Button("Export as PDF") { sharePDF() }
            }

            Section("Trips") {
                ForEach(trips.sorted(by: { $0.date > $1.date })) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripRowView(trip: trip)
                    }
                }
            }
        }
        .navigationTitle(quarter.displayString)
    }

    private func shareCSV() {
        let csv = CSVExporter.export(quarter: quarter, trips: trips)
        share(text: csv, filename: "\(quarter.id)-mileage.csv")
    }

    private func shareMarkdown() {
        let md = MarkdownExporter.export(quarter: quarter, trips: trips)
        share(text: md, filename: "\(quarter.id)-mileage.md")
    }

    private func sharePDF() {
        guard let data = PDFExporter.export(quarter: quarter, trips: trips) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(quarter.id)-mileage.pdf")
        try? data.write(to: url)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av)
    }

    private func share(text: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av)
    }

    private func present(_ av: UIActivityViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(av, animated: true)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add quarter list and detail views with paid status"
```

---

### Task 7: Export Services

**Files:**
- Create: `Miles/Export/CSVExporter.swift`
- Create: `Miles/Export/MarkdownExporter.swift`
- Create: `Miles/Export/PDFExporter.swift`

- [ ] **Step 1: Create CSVExporter.swift**

```swift
import Foundation

struct CSVExporter {
    static func export(quarter: Quarter, trips: [Trip]) -> String {
        var lines: [String] = []
        lines.append("Date,Origin,Destination,Distance (mi),Round Trip,Rate (¢/mi),Reimbursement ($),Purpose")

        var totalMiles = 0.0
        var totalReimbursement = 0.0

        for trip in trips.sorted(by: { $0.date < $1.date }) {
            let date = trip.date.formatted(date: .numeric, time: .omitted)
            let dist = trip.effectiveDistanceRounded
            let amt = trip.reimbursementTotal
            totalMiles += dist
            totalReimbursement += amt

            lines.append([
                csv(date),
                csv(trip.originAddress),
                csv(trip.destinationAddress),
                String(format: "%.1f", dist),
                trip.isRoundTrip ? "Yes" : "No",
                "\(trip.rateCentsPerMile)",
                String(format: "%.2f", amt),
                csv(trip.purpose)
            ].joined(separator: ","))
        }

        lines.append("")
        lines.append("Total,,\(String(format: "%.1f", totalMiles)),,,\(String(format: "%.2f", totalReimbursement)),")
        return lines.joined(separator: "\n")
    }

    private static func csv(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
```

- [ ] **Step 2: Create MarkdownExporter.swift**

```swift
import Foundation

struct MarkdownExporter {
    static func export(quarter: Quarter, trips: [Trip]) -> String {
        var md = "# Mileage Report — \(quarter.displayString)\n\n"
        md += "| Date | Origin | Destination | Distance (mi) | Round Trip | Rate | Reimbursement | Purpose |\n"
        md += "|------|--------|-------------|--------------|-----------|------|---------------|--------|\n"

        var totalMiles = 0.0
        var totalReimbursement = 0.0

        for trip in trips.sorted(by: { $0.date < $1.date }) {
            let dist = trip.effectiveDistanceRounded
            let amt = trip.reimbursementTotal
            totalMiles += dist
            totalReimbursement += amt

            md += "| \(trip.date.formatted(date: .numeric, time: .omitted)) "
            md += "| \(escapeMarkdown(trip.originAddress)) "
            md += "| \(escapeMarkdown(trip.destinationAddress)) "
            md += "| \(String(format: "%.1f", dist)) "
            md += "| \(trip.isRoundTrip ? "Yes" : "No") "
            md += "| \(trip.rateCentsPerMile)¢ "
            md += "| $\(String(format: "%.2f", amt)) "
            md += "| \(escapeMarkdown(trip.purpose)) |\n"
        }

        md += "\n"
        md += "**Total Miles:** \(String(format: "%.1f", totalMiles))\n"
        md += "**Total Reimbursement:** $\(String(format: "%.2f", totalReimbursement))\n"
        return md
    }

    private static func escapeMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
    }
}
```

- [ ] **Step 3: Create PDFExporter.swift**

```swift
import SwiftUI
import PDFKit

struct PDFExporter {
    static func export(quarter: Quarter, trips: [Trip]) -> Data? {
        let summary = PDFSummaryView(quarter: quarter, trips: trips)
        let hosting = UIHostingController(rootView: summary)
        let size = CGSize(width: 612, height: 792)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.backgroundColor = .white

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            hosting.view.layer.render(in: ctx.cgContext)
        }
    }
}

struct PDFSummaryView: View {
    let quarter: Quarter
    let trips: [Trip]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mileage Report — \(quarter.displayString)")
                .font(.title)
                .padding(.bottom, 8)

            let totalMiles = quarter.totalMiles(for: trips)
            let totalReimbursement = quarter.totalReimbursement(for: trips)

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Miles:")
                        .font(.headline)
                    Text("\(String(format: "%.1f", totalMiles))")
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Total Reimbursement:")
                        .font(.headline)
                    Text("$\(String(format: "%.2f", totalReimbursement))")
                }
            }
            .padding(.bottom, 8)

            Divider()

            ForEach(trips.sorted(by: { $0.date < $1.date })) { trip in
                HStack {
                    Text(trip.date.formatted(date: .numeric, time: .omitted))
                        .frame(width: 80, alignment: .leading)
                        .font(.caption)
                    Text(trip.originAddress)
                        .font(.caption)
                        .lineLimit(1)
                    Text("→")
                        .font(.caption)
                    Text(trip.destinationAddress)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(String(format: "%.1f", trip.effectiveDistanceRounded)) mi")
                        .font(.caption)
                        .frame(width: 50, alignment: .trailing)
                    Text("$\(String(format: "%.2f", trip.reimbursementTotal))")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                }
                Divider()
            }
        }
        .padding(40)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add CSV, Markdown, and PDF export services"
```

---

### Task 8: Settings View

**Files:**
- Create: `Miles/Views/SettingsView.swift`
- Create: `Miles/Views/FrequentDestinationListView.swift`
- Create: `Miles/Views/FrequentDestinationFormView.swift`

- [ ] **Step 1: Create SettingsView.swift**

```swift
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
```

- [ ] **Step 2: Create FrequentDestinationListView.swift**

```swift
import SwiftUI
import SwiftData

struct FrequentDestinationListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FrequentDestination.name) private var destinations: [FrequentDestination]

    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            List {
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
            }
            .navigationTitle("Destinations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingForm = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingForm) {
                FrequentDestinationFormView()
            }
        }
    }
}
```

- [ ] **Step 3: Create FrequentDestinationFormView.swift**

```swift
import SwiftUI
import SwiftData

struct FrequentDestinationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var address: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Address", text: $address, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle("New Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let dest = FrequentDestination(name: name, address: address)
                        context.insert(dest)
                        dismiss()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add settings view with rate lookup and destination management"
```

---

### Task 9: Wire Up Remaining Stubs + Polish

**Files:**
- Modify: Remove all placeholder stub views (they're replaced by the real implementations above)

- [ ] **Step 1: Verify compilation**

Check that the project builds. Open `Miles.xcodeproj` in Xcode, ensure all files are added to the target, and Product > Build (Cmd+B) succeeds.

- [ ] **Step 2: Run on Simulator**

Verify tab navigation works, data entry works, quarter grouping works, and export produces valid files.

- [ ] **Step 3: Commit final project state**

```bash
git add -A && git commit -m "feat: complete mileage tracker implementation"
```

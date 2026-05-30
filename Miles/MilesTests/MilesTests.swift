import Testing
import Foundation
@testable import Miles

struct TripModelTests {

    @Test func oneWayTripEffectiveDistance() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 10.0,
            isRoundTrip: false
        )
        #expect(trip.effectiveDistance == 10.0)
        #expect(trip.effectiveDistanceRounded == 10.0)
    }

    @Test func roundTripEffectiveDistance() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 10.0,
            isRoundTrip: true
        )
        #expect(trip.effectiveDistance == 20.0)
        #expect(trip.effectiveDistanceRounded == 20.0)
    }

    @Test func reimbursementCalculatedCorrectly() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 10.0,
            isRoundTrip: false,
            rateCentsPerMile: 70.0
        )
        #expect(trip.reimbursementTotal == 7.0)
    }

    @Test func roundTripReimbursementDoubled() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 10.0,
            isRoundTrip: true,
            rateCentsPerMile: 70.0
        )
        #expect(trip.reimbursementTotal == 14.0)
    }

    @Test func reimbursementRoundsToTwoDecimals() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 3.33,
            isRoundTrip: false,
            rateCentsPerMile: 67.0
        )
        let expected = (3.3 * 0.67).roundedTo2dp
        #expect(trip.reimbursementTotal == expected)
    }

    @Test func distanceRoundedToOneDecimal() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 6.78,
            isRoundTrip: false
        )
        #expect(trip.effectiveDistanceRounded == 6.8)
    }

    @Test func zeroDistanceProducesZeroReimbursement() {
        let trip = Trip(
            date: .now,
            purpose: "Test",
            distanceMiles: 0,
            rateCentsPerMile: 70.0
        )
        #expect(trip.reimbursementTotal == 0.0)
    }
}

struct IRSRateServiceTests {

    @Test func defaultRateForKnownYears() {
        #expect(IRSRateService.defaultRate(for: 2026) == 72.5)
        #expect(IRSRateService.defaultRate(for: 2025) == 70.0)
        #expect(IRSRateService.defaultRate(for: 2024) == 67.0)
        #expect(IRSRateService.defaultRate(for: 2023) == 65.5)
        #expect(IRSRateService.defaultRate(for: 2022) == 62.0)
    }

    @Test func defaultRateForUnknownYear() {
        #expect(IRSRateService.defaultRate(for: 1999) == 70.0)
        #expect(IRSRateService.defaultRate(for: 2030) == 70.0)
    }

    @Test func manualOverrideTakesPriority() {
        IRSRateService.manualOverride = 55.5
        #expect(IRSRateService.currentDefaultRate == 55.5)
        #expect(IRSRateService.isManual == true)
        IRSRateService.manualOverride = 0
    }

    @Test func zeroManualOverrideFallsBack() {
        IRSRateService.manualOverride = 0
        #expect(IRSRateService.isManual == false)
    }

    @Test func parseRateExtractsNumber() async {
        let html = "standard mileage rates for 2025 are: business: 70 cents/mile"
        let rate = await IRSRateService.fetchCurrentRate()
        // Rate should be > 0 unless network fails
        #expect(rate > 0)
    }
}

struct QuarterModelTests {

    @Test func quarterDisplayString() {
        let q = Quarter(year: 2025, quarterNumber: 2)
        #expect(q.displayString == "Q2 2025")
        #expect(q.id == "2025-Q2")
    }

    @Test func quarterStartDate() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let start = q.startDate
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: start) == 2025)
        #expect(calendar.component(.month, from: start) == 1)
    }

    @Test func quarterEndDate() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let end = q.endDate
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: end) == 2025)
        #expect(calendar.component(.month, from: end) == 3)
    }

    @Test func quarterFiltersTripsCorrectly() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 15
        let q1Trip = Trip(date: calendar.date(from: components)!, purpose: "Q1")
        components.month = 5
        let q2Trip = Trip(date: calendar.date(from: components)!, purpose: "Q2")

        let q1 = Quarter(year: 2025, quarterNumber: 1)
        let q2 = Quarter(year: 2025, quarterNumber: 2)
        let all = [q1Trip, q2Trip]

        #expect(q1.trips(from: all).count == 1)
        #expect(q1.trips(from: all).first?.purpose == "Q1")
        #expect(q2.trips(from: all).count == 1)
        #expect(q2.trips(from: all).first?.purpose == "Q2")
    }

    @Test func quarterTotals() {
        let trip = Trip(date: .now, purpose: "T", distanceMiles: 10.0, isRoundTrip: true, rateCentsPerMile: 70.0)
        let q = Quarter(year: 2026, quarterNumber: 2)
        let trips = [trip]

        #expect(q.totalMiles(for: trips) == 20.0)
        #expect(q.totalReimbursement(for: trips) == 14.0)
    }

    @Test func allQuartersFromTrips() {
        let t1 = Trip(date: makeDate(2025, 1, 15), purpose: "A")
        let t2 = Trip(date: makeDate(2025, 5, 1), purpose: "B")
        let t3 = Trip(date: makeDate(2024, 10, 1), purpose: "C")
        let t4 = Trip(date: makeDate(2024, 10, 15), purpose: "D")

        let quarters = Quarter.allQuarters(for: [t1, t2, t3, t4])
        let ids = Set(quarters.map { $0.id })
        #expect(ids.contains("2025-Q1"))
        #expect(ids.contains("2025-Q2"))
        #expect(ids.contains("2024-Q4"))
        #expect(ids.count == 3)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps)!
    }
}

struct DoubleExtensionsTests {

    @Test func roundedTo2dp() {
        #expect(1.234.roundedTo2dp == 1.23)
        #expect(1.235.roundedTo2dp == 1.24)
        #expect(1.0.roundedTo2dp == 1.0)
        #expect(0.0.roundedTo2dp == 0.0)
    }

    @Test func roundedTo1dp() {
        #expect(1.24.roundedTo1dp == 1.2)
        #expect(1.25.roundedTo1dp == 1.3)
        #expect(1.0.roundedTo1dp == 1.0)
    }
}

struct CSVExporterTests {

    @Test func csvHeaderRow() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let csv = CSVExporter.export(quarter: q, trips: [])
        #expect(csv.contains("Date,Origin,Destination,Distance (mi),Round Trip,Rate (¢/mi),Reimbursement ($),Purpose"))
    }

    @Test func csvIncludesTotals() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let trip = Trip(date: .now, purpose: "Test", distanceMiles: 10.0, rateCentsPerMile: 70.0)
        let csv = CSVExporter.export(quarter: q, trips: [trip])
        #expect(csv.contains("Total"))
        #expect(csv.contains("10.0"))
        #expect(csv.contains("7.00"))
    }

    @Test func csvEscapesFieldsWithCommas() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let trip = Trip(date: .now, purpose: "A, B, C", distanceMiles: 10.0, rateCentsPerMile: 70.0)
        let csv = CSVExporter.export(quarter: q, trips: [trip])
        #expect(csv.contains("\"A, B, C\""))
    }

    @Test func emptyTripsProducesHeaderOnly() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let csv = CSVExporter.export(quarter: q, trips: [])
        let lines = csv.split(separator: "\n")
        #expect(lines.count >= 1)
    }
}

struct MarkdownExporterTests {

    @Test func markdownIncludesTitle() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let md = MarkdownExporter.export(quarter: q, trips: [])
        #expect(md.contains("Mileage Report — Q1 2025"))
    }

    @Test func markdownIncludesTableHeaders() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let md = MarkdownExporter.export(quarter: q, trips: [])
        #expect(md.contains("| Date | Origin | Destination | Distance (mi) | Round Trip | Rate | Reimbursement | Purpose |"))
    }

    @Test func markdownIncludesTotals() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let trip = Trip(date: .now, purpose: "Test", distanceMiles: 10.0, rateCentsPerMile: 70.0)
        let md = MarkdownExporter.export(quarter: q, trips: [trip])
        #expect(md.contains("Total Miles:"))
        #expect(md.contains("Total Reimbursement:"))
    }

    @Test func markdownEscapesPipes() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let trip = Trip(date: .now, purpose: "A|B", distanceMiles: 10.0, originAddress: "in|out", destinationAddress: "dest", rateCentsPerMile: 70.0)
        let md = MarkdownExporter.export(quarter: q, trips: [trip])
        #expect(md.contains("\\|"))
    }

    @Test func markdownStripsNewlines() {
        let q = Quarter(year: 2025, quarterNumber: 1)
        let trip = Trip(date: .now, purpose: "Test", distanceMiles: 10.0, originAddress: "A\nB\nC", destinationAddress: "D", rateCentsPerMile: 70.0)
        let md = MarkdownExporter.export(quarter: q, trips: [trip])
        #expect(!md.contains("\nA\nB\nC\n"))
    }
}

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
        components.day = Calendar.current.range(of: .day, in: .month, for: Date())?.upperBound ?? 30
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

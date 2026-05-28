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
                String(format: "%.1f", trip.rateCentsPerMile),
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

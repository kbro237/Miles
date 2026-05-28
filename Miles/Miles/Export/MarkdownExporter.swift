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
            md += "| \(String(format: "%.1f", trip.rateCentsPerMile))¢ "
            md += "| $\(String(format: "%.2f", amt)) "
            md += "| \(escapeMarkdown(trip.purpose)) |\n"
        }

        md += "\n"
        md += "**Total Miles:** \(String(format: "%.1f", totalMiles))\n"
        md += "**Total Reimbursement:** $\(String(format: "%.2f", totalReimbursement))\n"
        return md
    }

    private static func escapeMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

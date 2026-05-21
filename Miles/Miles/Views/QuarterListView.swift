import SwiftUI
import SwiftData

struct QuarterListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]
    @Query private var paidQuarters: [PaidQuarter]

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
                            get: { isQuarterPaid(quarter.id) },
                            set: { newValue in
                                if newValue {
                                    let pq = PaidQuarter(quarterID: quarter.id)
                                    context.insert(pq)
                                } else if let existing = paidQuarters.first(where: { $0.quarterID == quarter.id }) {
                                    context.delete(existing)
                                }
                                try? context.save()
                            }
                        )
                    )) {
                        QuarterRowView(
                            quarter: quarter,
                            trips: quarter.trips(from: trips),
                            isPaid: isQuarterPaid(quarter.id)
                        )
                    }
                }
            }
            .navigationTitle("Quarters")
        }
    }

    private func isQuarterPaid(_ quarterID: String) -> Bool {
        paidQuarters.contains { $0.quarterID == quarterID }
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

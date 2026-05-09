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

import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]

    @State private var showingForm = false
    @State private var sheetID = UUID()

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
                    Button(action: {
                        sheetID = UUID()
                        showingForm = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                TripFormView()
                    .id(sheetID)
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

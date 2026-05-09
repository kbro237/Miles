import SwiftUI

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        List {
            Section("Trip Details") {
                LabeledContent("Date") {
                    Text(trip.date, style: .date)
                }
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

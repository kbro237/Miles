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

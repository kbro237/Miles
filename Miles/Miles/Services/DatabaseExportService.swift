import Foundation
import SwiftData

struct TripExport: Codable {
    var date: Date
    var purpose: String
    var distanceMiles: Double
    var isRoundTrip: Bool
    var rateCentsPerMile: Int
    var originAddress: String
    var destinationAddress: String
    var notes: String?
    var destinationName: String?
}

struct DestinationExport: Codable {
    var name: String
    var address: String
}

struct DatabaseExport: Codable {
    var trips: [TripExport]
    var destinations: [DestinationExport]
    var paidQuarters: [String]
}

struct DatabaseExportService {

    static func exportData(trips: [Trip], destinations: [FrequentDestination]) -> Data? {
        let paidKey = "paidQuarters"
        let paidQuarters = UserDefaults.standard.stringArray(forKey: paidKey) ?? []

        let export = DatabaseExport(
            trips: trips.map { trip in
                TripExport(
                    date: trip.date,
                    purpose: trip.purpose,
                    distanceMiles: trip.distanceMiles,
                    isRoundTrip: trip.isRoundTrip,
                    rateCentsPerMile: trip.rateCentsPerMile,
                    originAddress: trip.originAddress,
                    destinationAddress: trip.destinationAddress,
                    notes: trip.notes,
                    destinationName: trip.destination?.name
                )
            },
            destinations: destinations.map {
                DestinationExport(name: $0.name, address: $0.address)
            },
            paidQuarters: paidQuarters
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(export)
    }

    static func importData(
        from data: Data,
        existingTrips: [Trip],
        existingDestinations: [FrequentDestination],
        context: ModelContext
    ) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(DatabaseExport.self, from: data)

        for trip in existingTrips {
            context.delete(trip)
        }
        for dest in existingDestinations {
            context.delete(dest)
        }

        var insertedDestinations: [FrequentDestination] = []
        for dest in export.destinations {
            let newDest = FrequentDestination(name: dest.name, address: dest.address)
            context.insert(newDest)
            insertedDestinations.append(newDest)
        }

        for trip in export.trips {
            let newTrip = Trip(
                date: trip.date,
                purpose: trip.purpose,
                distanceMiles: trip.distanceMiles,
                isRoundTrip: trip.isRoundTrip,
                rateCentsPerMile: trip.rateCentsPerMile,
                originAddress: trip.originAddress,
                destinationAddress: trip.destinationAddress,
                notes: trip.notes
            )
            if let destName = trip.destinationName,
               let matchedDest = insertedDestinations.first(where: { $0.name == destName }) {
                newTrip.destination = matchedDest
            }
            context.insert(newTrip)
        }

        try context.save()
        UserDefaults.standard.set(export.paidQuarters, forKey: "paidQuarters")
    }
}

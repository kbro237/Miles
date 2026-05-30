import Foundation
import SwiftData

struct SyncService {
    private let defaults = UserDefaults.standard
    private static let tokenKey = "sync_token"
    private static let endpointKey = "sync_endpoint"

    static var isConfigured: Bool {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: tokenKey) != nil &&
               defaults.string(forKey: endpointKey) != nil
    }

    static var storedToken: String {
        UserDefaults.standard.string(forKey: tokenKey) ?? ""
    }

    static var storedEndpoint: String {
        UserDefaults.standard.string(forKey: endpointKey) ?? ""
    }

    static func configure(token: String, endpoint: String) {
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: tokenKey)
        defaults.set(endpoint, forKey: endpointKey)
    }

    static func clearConfig() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: endpointKey)
        for key in ["trips", "destinations", "paidQuarters"] {
            defaults.removeObject(forKey: "sync_version_\(key)")
        }
    }

    func makeProvider() -> SyncProvider? {
        guard SyncService.isConfigured else { return nil }
        let token = SyncService.storedToken
        guard let url = URL(string: SyncService.storedEndpoint) else { return nil }
        return CloudflareSyncClient(
            token: token,
            endpoint: url,
            device: deviceID(),
            defaults: defaults
        )
    }

    func pull(provider: SyncProvider, trips: [Trip], destinations: [FrequentDestination], paidQuarters: [PaidQuarter], context: ModelContext) async throws -> Bool {
        let remote = try await provider.pull()
        guard !remote.isEmpty else { return false }

        if let tripsData = remote["trips"]?.value,
           let data = tripsData.data(using: .utf8),
           let export = try? JSONDecoder().decode(DatabaseExport.self, from: data) {
            for trip in trips { context.delete(trip) }
            for dest in destinations { context.delete(dest) }
            for pq in paidQuarters { context.delete(pq) }
            var insertedDests: [FrequentDestination] = []
            for d in export.destinations {
                let dest = FrequentDestination(name: d.name, address: d.address)
                context.insert(dest)
                insertedDests.append(dest)
            }
            for t in export.trips {
                let trip = Trip(
                    date: t.date,
                    purpose: t.purpose,
                    distanceMiles: t.distanceMiles,
                    isRoundTrip: t.isRoundTrip,
                    rateCentsPerMile: t.rateCentsPerMile,
                    originAddress: t.originAddress,
                    destinationAddress: t.destinationAddress,
                    notes: t.notes
                )
                if let destName = t.destinationName,
                   let matched = insertedDests.first(where: { $0.name == destName }) {
                    trip.destination = matched
                }
                context.insert(trip)
            }
            for qid in export.paidQuarters {
                context.insert(PaidQuarter(quarterID: qid))
            }
            try context.save()
        }

        if let destsData = remote["destinations"]?.value,
           let data = destsData.data(using: .utf8),
           let dests = try? JSONDecoder().decode([DestinationExport].self, from: data) {
            for dest in destinations { context.delete(dest) }
            for d in dests {
                context.insert(FrequentDestination(name: d.name, address: d.address))
            }
        }

        if let pqData = remote["paidQuarters"]?.value,
           let data = pqData.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            for pq in paidQuarters { context.delete(pq) }
            for id in ids {
                context.insert(PaidQuarter(quarterID: id))
            }
        }

        try context.save()
        return true
    }

    func push(provider: SyncProvider, trips: [Trip], destinations: [FrequentDestination], paidQuarters: [PaidQuarter]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let tripsExport = DatabaseExport(
            trips: trips.map { t in
                TripExport(
                    date: t.date, purpose: t.purpose,
                    distanceMiles: t.distanceMiles, isRoundTrip: t.isRoundTrip,
                    rateCentsPerMile: t.rateCentsPerMile,
                    originAddress: t.originAddress, destinationAddress: t.destinationAddress,
                    notes: t.notes, destinationName: t.destination?.name
                )
            },
            destinations: destinations.map { DestinationExport(name: $0.name, address: $0.address) },
            paidQuarters: paidQuarters.map { $0.quarterID }
        )

        guard let tripsJSON = String(data: try encoder.encode(tripsExport), encoding: .utf8),
              let destsJSON = String(data: try encoder.encode(destinations.map { DestinationExport(name: $0.name, address: $0.address) }), encoding: .utf8),
              let pqJSON = String(data: try encoder.encode(paidQuarters.map { $0.quarterID }), encoding: .utf8) else { return }

        let tripVersion = defaults.integer(forKey: "sync_version_trips")
        let destVersion = defaults.integer(forKey: "sync_version_destinations")
        let pqVersion = defaults.integer(forKey: "sync_version_paidQuarters")

        let entries: [(key: String, value: String, version: Int)] = [
            ("trips", tripsJSON, tripVersion),
            ("destinations", destsJSON, destVersion),
            ("paidQuarters", pqJSON, pqVersion),
        ]

        _ = try await provider.push(entries: entries)
    }

    private func deviceID() -> String {
        let key = "sync_device_id"
        if let existing = defaults.string(forKey: key) { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: key)
        return id
    }
}

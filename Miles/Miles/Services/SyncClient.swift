import Foundation

protocol SyncProvider {
    func pull() async throws -> [String: (value: String, version: Int)]
    func push(entries: [(key: String, value: String, version: Int)]) async throws -> [String: Int]
}

final class CloudflareSyncClient: SyncProvider {
    private let token: String
    private let endpoint: URL
    private let device: String
    private let defaults: UserDefaults

    init(token: String, endpoint: URL, device: String, defaults: UserDefaults = .standard) {
        self.token = token
        self.endpoint = endpoint
        self.device = device
        self.defaults = defaults
    }

    func pull() async throws -> [String: (value: String, version: Int)] {
        let versions = defaults.knownVersions()
        let body: [String: Any] = [
            "token": token,
            "device": device,
            "versions": versions,
        ]
        let data = try await post(apiPath: "/sync/pull", body: body)
        let response = try JSONDecoder().decode(PullResponse.self, from: data)
        var result: [String: (value: String, version: Int)] = [:]
        for entry in response.entries {
            result[entry.key] = (value: entry.value, version: entry.version)
        }
        for (key, version) in response.latest ?? [:] {
            defaults.setVersion(version, forKey: key)
        }
        return result
    }

    func push(entries: [(key: String, value: String, version: Int)]) async throws -> [String: Int] {
        let entriesJSON = entries.map { ["key": $0.key, "value": $0.value, "ver": $0.version] }
        let body: [String: Any] = [
            "token": token,
            "device": device,
            "entries": entriesJSON,
        ]
        let data = try await post(apiPath: "/sync/push", body: body)
        let response = try JSONDecoder().decode(PushResponse.self, from: data)
        var result: [String: Int] = [:]
        for resolved in response.resolved {
            result[resolved.key] = resolved.version
            defaults.setVersion(resolved.version, forKey: resolved.key)
        }
        return result
    }

    private func post(apiPath: String, body: [String: Any]) async throws -> Data {
        var urlString = endpoint.absoluteString
        while urlString.hasSuffix("/") { urlString.removeLast() }
        guard let url = URL(string: "\(urlString)/\(apiPath)") else {
            throw SyncError.badResponse(status: 0)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SyncError.badResponse(status: status)
        }
        return data
    }
}

enum SyncError: LocalizedError {
    case badResponse(status: Int)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): return "Sync server returned HTTP \(status)."
        case .notConfigured: return "Sync is not configured. Set your token and endpoint in Settings."
        }
    }
}

private struct PullResponse: Codable {
    let entries: [PullEntry]
    let latest: [String: Int]?

    struct PullEntry: Codable {
        let key: String
        let value: String
        let version: Int

        enum CodingKeys: String, CodingKey {
            case key, value, version = "ver"
        }
    }
}

private struct PushResponse: Codable {
    let resolved: [ResolvedEntry]

    struct ResolvedEntry: Codable {
        let key: String
        let version: Int

        enum CodingKeys: String, CodingKey {
            case key, version = "ver"
        }
    }
}

private extension UserDefaults {
    private static let versionPrefix = "sync_version_"

    func knownVersions() -> [String: Int] {
        var versions: [String: Int] = [:]
        for key in ["trips", "destinations", "paidQuarters"] {
            let v = integer(forKey: "\(Self.versionPrefix)\(key)")
            if v > 0 { versions[key] = v }
        }
        return versions
    }

    func setVersion(_ version: Int, forKey key: String) {
        set(version, forKey: "\(Self.versionPrefix)\(key)")
    }
}

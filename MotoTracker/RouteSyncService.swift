import Foundation

// Syncs saved routes to/from a JSON file in the public MotoTracker GitHub repo.
// Reading uses the GitHub Contents API without auth (public repo, no caching).
// Writing uses the API with the stored token.
// Conflict resolution: merge by UUID, keep route with more recent date.

enum RouteSyncService {

    private static let repoOwner = "brianwhitman71-cell"
    private static let repoName  = "MotoTracker"
    private static let filePath  = "sync/routes.json"
    private static let apiURL    = "https://api.github.com/repos/brianwhitman71-cell/MotoTracker/contents/sync/routes.json"

    private struct SyncPayload: Codable {
        let schemaVersion: Int
        let routes: [SavedRoute]
    }

    private static var iso8601Encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    private static var iso8601Decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Fetch

    /// Reads routes from GitHub Contents API — no auth needed for public repo.
    /// Also returns the file SHA needed for subsequent writes.
    static func fetchRoutes() async throws -> (routes: [SavedRoute], sha: String?) {
        guard let url = URL(string: apiURL) else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if http.statusCode == 404 { return ([], nil) }
        guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sha     = json["sha"] as? String,
            let encoded = json["content"] as? String
        else { throw URLError(.cannotParseResponse) }

        let clean = encoded.replacingOccurrences(of: "\n", with: "")
        guard let decoded = Data(base64Encoded: clean) else { throw URLError(.cannotDecodeContentData) }

        let payload = try iso8601Decoder.decode(SyncPayload.self, from: decoded)
        return (payload.routes, sha)
    }

    // MARK: - Upload

    /// Uploads the full routes list. Returns the new file SHA on success.
    /// Automatically retries once with a fresh SHA if a conflict (422) is returned.
    @discardableResult
    static func uploadRoutes(_ routes: [SavedRoute], sha: String?) async throws -> String? {
        return try await attemptUpload(routes: routes, sha: sha, isRetry: false)
    }

    private static func attemptUpload(routes: [SavedRoute], sha: String?, isRetry: Bool) async throws -> String? {
        let payload  = SyncPayload(schemaVersion: 1, routes: routes)
        let jsonData = try iso8601Encoder.encode(payload)

        guard let url = URL(string: apiURL) else { throw URLError(.badURL) }

        var body: [String: Any] = [
            "message": "Sync routes",
            "content": jsonData.base64EncodedString()
        ]
        if let sha = sha { body["sha"] = sha }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(Secrets.githubBugToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        // 409 or 422 = SHA conflict — fetch fresh SHA and retry once
        if (http.statusCode == 409 || http.statusCode == 422) && !isRetry {
            let freshSHA = await fetchCurrentSHA()
            return try await attemptUpload(routes: routes, sha: freshSHA, isRetry: true)
        }

        guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [String: Any]
        return content?["sha"] as? String
    }

    /// Fetches only the current file SHA from the GitHub API.
    static func fetchCurrentSHA() async -> String? {
        guard let url = URL(string: apiURL) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(Secrets.githubBugToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["sha"] as? String
    }

    // MARK: - Merge

    /// Merges local and remote route lists.
    /// Same UUID → keep the one with the more recent date.
    /// Unique UUID → include it.
    static func merge(local: [SavedRoute], remote: [SavedRoute]) -> [SavedRoute] {
        var byID: [UUID: SavedRoute] = [:]
        for r in local  { byID[r.id] = r }
        for r in remote {
            if let existing = byID[r.id] {
                if r.date > existing.date { byID[r.id] = r }
            } else {
                byID[r.id] = r
            }
        }
        return byID.values.sorted { $0.date > $1.date }
    }
}

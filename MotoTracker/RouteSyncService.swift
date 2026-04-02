import Foundation

// Syncs saved routes to/from a JSON file in the GitHub repo.
// Both the iOS app and the web planner read/write the same file.
// Conflict resolution: merge by UUID, keep route with more recent date.

enum RouteSyncService {

    private static let repoOwner = "brianwhitman71-cell"
    private static let repoName  = "MotoTracker"
    private static let filePath  = "sync/routes.json"
    // Raw URL is publicly readable without auth (public repo)
    private static let rawURL    = "https://raw.githubusercontent.com/brianwhitman71-cell/MotoTracker/main/sync/routes.json"

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

    /// Fetches routes from the public raw URL (no auth required).
    /// Also fetches the file SHA via the API so uploads can update the file.
    static func fetchRoutes() async throws -> (routes: [SavedRoute], sha: String?) {
        // Read content from raw URL — no token needed, works for all users
        guard let url = URL(string: rawURL) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 { return ([], nil) }
        guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let payload = try iso8601Decoder.decode(SyncPayload.self, from: data)

        // Fetch SHA separately (needed for writes) — best-effort, authenticated
        let sha = await fetchSHA()
        return (payload.routes, sha)
    }

    /// Fetches only the file SHA from the GitHub API (needed to update an existing file).
    static func fetchSHA() async -> String? {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(filePath)"
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(Secrets.githubBugToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["sha"] as? String
    }

    // MARK: - Upload

    /// Uploads the full routes list to GitHub.
    /// Pass the SHA returned by fetchRoutes to update an existing file.
    static func uploadRoutes(_ routes: [SavedRoute], sha: String?) async throws {
        let payload  = SyncPayload(schemaVersion: 1, routes: routes)
        let jsonData = try iso8601Encoder.encode(payload)

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(filePath)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

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

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Merge

    /// Merges local and remote route lists.
    /// - Same UUID: keep the one with the more recent date.
    /// - Unique UUID: include it in the result.
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

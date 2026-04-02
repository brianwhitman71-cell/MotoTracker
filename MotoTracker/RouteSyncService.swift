import Foundation

// Syncs saved routes to/from a JSON file in the GitHub repo.
// Both the iOS app and the web planner read/write the same file.
// Conflict resolution: merge by UUID, keep route with more recent date.

enum RouteSyncService {

    private static let repoOwner = "brianwhitman71-cell"
    private static let repoName  = "mototracker-bugs"
    private static let filePath  = "sync/routes.json"

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

    /// Returns the routes stored on GitHub and the file SHA (needed for updates).
    static func fetchRoutes() async throws -> (routes: [SavedRoute], sha: String?) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(filePath)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(Secrets.githubBugToken)", forHTTPHeaderField: "Authorization")
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

        // GitHub wraps base64 content in newlines
        let clean   = encoded.replacingOccurrences(of: "\n", with: "")
        guard let decoded = Data(base64Encoded: clean) else { throw URLError(.cannotDecodeContentData) }

        let payload = try iso8601Decoder.decode(SyncPayload.self, from: decoded)
        return (payload.routes, sha)
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

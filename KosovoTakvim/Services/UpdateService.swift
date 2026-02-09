import Foundation

struct UpdateService {
    static let currentVersion = "1.2.1"

    private static let repo = "drilonjaha/Takvimi-i-Kosoves-per-MacOS"
    private static let apiURL = "https://api.github.com/repos/\(repo)/releases/latest"

    struct UpdateInfo {
        let available: Bool
        let version: String?
        let downloadURL: URL?
    }

    static func checkForUpdate() async -> UpdateInfo {
        guard let url = URL(string: apiURL) else {
            return UpdateInfo(available: false, version: nil, downloadURL: nil)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return UpdateInfo(available: false, version: nil, downloadURL: nil)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return UpdateInfo(available: false, version: nil, downloadURL: nil)
            }

            // Strip "v" prefix from tag
            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            // Find DMG asset download URL
            var dmgURL: URL? = nil
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.hasSuffix(".dmg"),
                       let urlString = asset["browser_download_url"] as? String {
                        dmgURL = URL(string: urlString)
                        break
                    }
                }
            }

            let isNewer = compareVersions(current: currentVersion, latest: latestVersion)

            return UpdateInfo(
                available: isNewer,
                version: latestVersion,
                downloadURL: dmgURL
            )
        } catch {
            return UpdateInfo(available: false, version: nil, downloadURL: nil)
        }
    }

    /// Returns true if `latest` is newer than `current`
    private static func compareVersions(current: String, latest: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(currentParts.count, latestParts.count)
        for i in 0..<maxCount {
            let c = i < currentParts.count ? currentParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}

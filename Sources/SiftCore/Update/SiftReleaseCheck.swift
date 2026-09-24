import Foundation

public struct SiftGitHubRelease: Decodable, Sendable, Equatable {
    public let tagName: String
    public let name: String?
    public let htmlURL: URL
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }

    public struct Asset: Decodable, Sendable, Equatable {
        public let name: String
        public let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    public var version: String { SiftVersionCompare.normalize(tagName) }

    /// The DMG when the release has one. Otherwise the release page.
    public var preferredDownloadURL: URL {
        assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })?.browserDownloadURL
            ?? htmlURL
    }
}

public enum SiftVersionCompare {
    public static func normalize(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    public static func isRemoteNewer(remote: String, local: String) -> Bool {
        compare(remote, local) == .orderedDescending
    }

    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = parse(normalize(lhs))
        let right = parse(normalize(rhs))
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b {
                return a > b ? .orderedDescending : .orderedAscending
            }
        }
        return .orderedSame
    }

    private static func parse(_ normalized: String) -> [Int] {
        normalized.split(separator: ".", omittingEmptySubsequences: false).map { part in
            let numeric = part.prefix { $0.isNumber }
            return Int(numeric) ?? 0
        }
    }
}

public enum SiftAppVersion {
    public static var current: String {
        let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let trimmed = bundled?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "0.1.2" : trimmed
    }
}

public enum SiftGitHubReleaseAPI {
    public static let latestURL = URL(string: "https://api.github.com/repos/Cyberesia/sift/releases/latest")!

    public static func fetchLatest(
        session: URLSession = .shared,
        localVersion: String = SiftAppVersion.current
    ) async throws -> SiftGitHubRelease {
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Sift/\(localVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SiftReleaseCheckError.invalidResponse
        }
        if http.statusCode == 404 {
            throw SiftReleaseCheckError.noRelease
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SiftReleaseCheckError.httpStatus(http.statusCode)
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> SiftGitHubRelease {
        do {
            return try JSONDecoder().decode(SiftGitHubRelease.self, from: data)
        } catch {
            throw SiftReleaseCheckError.decodingFailed
        }
    }
}

public enum SiftReleaseCheckError: LocalizedError, Equatable {
    case invalidResponse
    case noRelease
    case httpStatus(Int)
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid update check response."
        case .noRelease:
            return "No release published yet."
        case .httpStatus(let code):
            return "Update check failed (HTTP \(code))."
        case .decodingFailed:
            return "Could not read the latest release information."
        }
    }
}

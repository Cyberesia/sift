import Foundation

public enum PhotoAssetURL {
    public static let scheme = "sift-photos"

    public static func make(localIdentifier: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "asset"
        components.queryItems = [URLQueryItem(name: "id", value: localIdentifier)]
        return components.url ?? URL(fileURLWithPath: "/tmp/invalid")
    }

    public static func localIdentifier(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        if let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "id" })?
            .value {
            return item
        }
        return url.host
    }
}

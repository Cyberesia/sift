import Foundation
import Security

/// One secret in the login keychain, read without ever raising the password dialog in the background.
public struct KeychainSecret: Sendable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public static let claudeAPIKey = KeychainSecret(service: "ai.sift.anthropic", account: "api-key")
    public static let localServerKey = KeychainSecret(service: "ai.sift.local-llm", account: "api-key")

    private static let cache = SecretCache()

    public var isConfigured: Bool { !(load() ?? "").isEmpty }

    public func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        SecItemDelete(baseQuery as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            Self.cache.store(nil, for: cacheKey)
            return
        }
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
        Self.cache.store(trimmed, for: cacheKey)
    }

    public func load() -> String? {
        if let remembered = Self.cache.value(for: cacheKey) { return remembered }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            Self.cache.store(nil, for: cacheKey)
            return nil
        }
        Self.cache.store(value, for: cacheKey)
        return value
    }

    private var cacheKey: String { service + "/" + account }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

private final class SecretCache: @unchecked Sendable {
    private let lock = NSLock()
    /// Outer optional: never read. Inner nil: read, nothing stored.
    private var values: [String: String?] = [:]

    func value(for key: String) -> String?? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func store(_ value: String?, for key: String) {
        lock.lock()
        values[key] = .some(value)
        lock.unlock()
    }
}

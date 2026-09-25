import Foundation
import Security

public enum JevCredential {
    private static let service = "ai.sift.typesafe"
    private static let account = "systemone"
    private static let cache = CredentialCache()

    /// Reads the keychain at most once, and never raises the password dialog.
    public static var isConfigured: Bool {
        if let cached = cache.remembered { return !(cached ?? "").isEmpty }
        return load(prompt: false) != nil
    }

    public static func save(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        SecItemDelete(baseQuery as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            cache.store(nil)
            return
        }
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
        cache.store(trimmed)
    }

    /// `prompt` is only for an explicit settings action. Background checks must not show the keychain dialog.
    public static func load(prompt: Bool = false) -> String? {
        if !prompt, let cached = cache.remembered { return cached }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if !prompt {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            if !prompt { cache.store(nil) }
            return nil
        }
        cache.store(token)
        return token
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

private final class CredentialCache: @unchecked Sendable {
    private let lock = NSLock()
    private var didRead = false
    private var token: String?

    /// `nil` means the keychain has not been read yet. `.some(nil)` means it was read and is empty.
    var remembered: String?? {
        lock.lock()
        defer { lock.unlock() }
        return didRead ? .some(token) : nil
    }

    func store(_ token: String?) {
        lock.lock()
        didRead = true
        self.token = token
        lock.unlock()
    }
}

public struct JevChoice: Sendable, Equatable {
    public let value: String
    public let confidence: Double
    public let uncertain: Bool

    public init(value: String, confidence: Double) {
        self.value = value
        self.confidence = confidence
        self.uncertain = confidence < 0.55
    }
}

public enum JevDecodeError: Error {
    case empty
    case malformed
}

/// Decodes a System One reply. Pixels stay on device; only the typed question result comes back.
public enum JevClient {
    public static let disclosure = "Jev receives the command, the allowed answers, and short catalog evidence: filename, extension, media kind, source folder, size, dates, dimensions, duration, scored labels, and up to three short OCR lines. While a document is indexed, a short outline can include opening lines, headings, sheet names, and column headers. The file itself, photos, video, and audio stay on this Mac."

    public static func decode(_ data: Data) throws -> JevChoice {
        let object = try JSONSerialization.jsonObject(with: data)
        if let choice = choice(from: object) { return choice }
        throw JevDecodeError.malformed
    }

    public static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!

    /// Sends text state and a bounded choice question. Returns nil when no key is stored. Pixels are not included.
    public static func ask(state: String, instructions: String, choices: [String: String]) async throws -> JevChoice? {
        guard let token = JevCredential.load(prompt: false) else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": "jev-latest",
            "state": state,
            "questions": [
                "decision": [
                    "type": "choice",
                    "instructions": instructions,
                    "criteria": choices,
                ],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode(data)
    }

    /// One yes/no score per key. Returns nil when no key is stored. Used once per document, at indexing.
    public static func askNouls(state: String, questions: [String: String]) async throws -> [String: Double]? {
        guard !questions.isEmpty, let token = JevCredential.load(prompt: false) else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encodedQuestions = questions.mapValues { instruction in
            ["type": "noul", "instructions": instruction]
        }
        let payload: [String: Any] = [
            "model": "jev-latest",
            "state": state,
            "questions": encodedQuestions,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decodeNouls(data)
    }

    /// One System One call classifies the assistant intent and readiness together.
    /// Deterministic code still extracts extensions, dates, folders, and counts.
    public static func askAssistant(state: String) async throws -> AssistantResult? {
        guard let token = JevCredential.load(prompt: false) else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let criteria = Dictionary(uniqueKeysWithValues: AssistantIntent.allCases.map {
            ($0.rawValue, $0.criterion)
        })
        let payload: [String: Any] = [
            "model": "jev-latest",
            "state": state,
            "questions": [
                "intent": [
                    "type": "choice",
                    "instructions": "What is the person asking Sift to do?",
                    "criteria": criteria,
                ],
                "readiness": [
                    "type": "score",
                    "instructions": "How complete is this file-management command?",
                    "criteria": [
                        "0": "Just started or too vague to preview",
                        "1": "Partly specified and safe only as a ghost preview",
                        "2": "Complete enough to prepare a dry run",
                    ],
                ],
                "needsReview": [
                    "type": "noul",
                    "instructions": "The command explicitly asks to review uncertainty, duplicates, or faces before organizing.",
                ],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decodeAssistant(data)
    }

    public static func decodeAssistant(_ data: Data) throws -> AssistantResult {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else { throw JevDecodeError.malformed }
        let answers = (dictionary["answers"] as? [String: Any]) ?? dictionary
        guard let intentObject = answers["intent"],
              let choice = choice(from: intentObject),
              let intent = AssistantIntent(rawValue: choice.value) else {
            throw JevDecodeError.malformed
        }
        let intentDictionary = intentObject as? [String: Any]
        let rawProbabilities = intentDictionary?["probabilities"] as? [String: Any]
        var probabilities: [AssistantIntent: Double] = [:]
        for candidate in AssistantIntent.allCases {
            if let value = jsonNumber(rawProbabilities?[candidate.rawValue]) {
                probabilities[candidate] = value
            }
        }
        if probabilities.isEmpty {
            probabilities[intent] = choice.confidence
            probabilities[.none] = max(0, 1 - choice.confidence)
        }
        let readinessRaw = score(from: answers["readiness"]) ?? 0.5
        let readiness = readinessRaw > 1 ? min(1, readinessRaw / 2) : max(0, readinessRaw)
        if (score(from: answers["needsReview"]) ?? 0) >= 0.65 {
            probabilities[.review] = max(probabilities[.review] ?? 0, 0.75)
        }
        return AssistantResult(probabilities: probabilities, readiness: readiness, engine: "jev")
    }

    public static func decodeNouls(_ data: Data) throws -> [String: Double] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else { throw JevDecodeError.malformed }
        let answers = (dict["answers"] as? [String: Any]) ?? [:]
        var scores: [String: Double] = [:]
        for (key, value) in answers {
            if let score = jsonNumber(value) {
                scores[key] = score
            } else if let nested = value as? [String: Any], let score = jsonNumber(nested["noul"]) {
                scores[key] = score
            }
        }
        return scores
    }

    private static func jsonNumber(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static func score(from object: Any?) -> Double? {
        if let direct = jsonNumber(object) { return direct }
        guard let dictionary = object as? [String: Any] else { return nil }
        for key in ["score", "value", "noul", "confidence"] {
            if let number = jsonNumber(dictionary[key]) { return number }
        }
        return nil
    }

    private static func choice(from object: Any) -> JevChoice? {
        if let dict = object as? [String: Any] {
            if let value = dict["value"] as? String {
                let confidence = (dict["confidence"] as? Double) ?? (dict["score"] as? Double) ?? 0
                return JevChoice(value: value, confidence: confidence)
            }
            if let content = dict["content"] as? String, let data = content.data(using: .utf8),
               let inner = try? JSONSerialization.jsonObject(with: data),
               let choice = choice(from: inner) {
                return choice
            }
            for key in ["result", "message", "choice"] {
                if let nested = dict[key], let choice = choice(from: nested) { return choice }
            }
            if let choices = dict["choices"] as? [Any] {
                for item in choices {
                    if let choice = choice(from: item) { return choice }
                }
            }
        }
        return nil
    }
}

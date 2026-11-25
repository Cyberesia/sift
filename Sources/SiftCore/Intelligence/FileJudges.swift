import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Rule drafting prompt

public enum RuleDraftPrompt {
    public static let system = """
    You turn a person's description of a folder automation into a rule for Sift, a Mac app. \
    Use only the folder and destination names you are given. Reply with JSON only.
    """

    public static func user(description: String, folderNames: [String], destinationNames: [String]) -> String {
        """
        Description: \(description)
        Folders Sift watches: \(folderNames.isEmpty ? "(none yet)" : folderNames.joined(separator: ", "))
        Destinations Sift may write to: \(destinationNames.isEmpty ? "(none yet)" : destinationNames.joined(separator: ", "))

        Fill:
        - "name": a short title, like "File invoices".
        - "watched_folder": one of the folders above, or "" if none fits.
        - "extensions": lowercase file extensions without dots, like ["pdf"], or [] for any file.
        - "check": what the file must be, as a noun phrase, like "an invoice or receipt", or "" for no check.
        - "fields": values to note, like ["vendor", "date", "amount"], or [].
        - "rename": a name template using {field}, {year}, {month}, {day}, {name}, like "{vendor} {date}", or "" to keep the name.
        - "destination": one of the destinations above, or "".
        - "subfolder": a path inside the destination using / and the same tokens, like "Invoices/{year}", or "".
        """
    }

    public static var schema: [String: Any] { [
        "type": "object",
        "properties": [
            "name": ["type": "string"],
            "watched_folder": ["type": "string"],
            "extensions": ["type": "array", "items": ["type": "string"]],
            "check": ["type": "string"],
            "fields": ["type": "array", "items": ["type": "string"]],
            "rename": ["type": "string"],
            "destination": ["type": "string"],
            "subfolder": ["type": "string"],
        ] as [String: Any],
        "required": ["name", "watched_folder", "extensions", "check", "fields", "rename", "destination", "subfolder"],
        "additionalProperties": false,
    ] }
}

// MARK: - Claude (Messages API over HTTPS; Swift has no official Anthropic SDK)

public struct ClaudeJudge: FileJudge {
    public let model: String
    public let apiKey: String
    public var endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public var session: URLSession = .shared

    public init(model: String, apiKey: String) {
        self.model = model.isEmpty ? IntelligenceSettings.defaultClaudeModel : model
        self.apiKey = apiKey
    }

    public var displayName: String { "Claude" }
    public var staysOnDevice: Bool { false }

    /// Models that accept server-side refusal fallbacks (`fallbacks: "default"`).
    static let fallbackModels: Set<String> = [
        "claude-fable-5-2", "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5",
    ]

    public func judge(_ request: FileJudgementRequest) async throws -> FileJudgement {
        let text = try await send(
            system: JudgementPrompt.system,
            user: JudgementPrompt.user(request),
            schema: JudgementPrompt.schema(fields: request.fields)
        )
        return try JudgementPrompt.parse(text, request: request, answeredBy: "Claude (\(model))")
    }

    public func draftRule(description: String, folderNames: [String], destinationNames: [String]) async throws -> Data? {
        let text = try await send(
            system: RuleDraftPrompt.system,
            user: RuleDraftPrompt.user(description: description, folderNames: folderNames, destinationNames: destinationNames),
            schema: RuleDraftPrompt.schema
        )
        return JSONText.firstObject(in: text).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
    }

    func requestBody(system: String, user: String, schema: [String: Any]) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4_096,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": [
                // Recognizing a document and copying three values is light work.
                "effort": "low",
                "format": ["type": "json_schema", "schema": schema],
            ] as [String: Any],
        ]
        if Self.fallbackModels.contains(model) {
            body["fallbacks"] = "default"
        }
        return body
    }

    func send(system: String, user: String, schema: [String: Any]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        if Self.fallbackModels.contains(model) {
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(system: system, user: user, schema: schema))
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw IntelligenceError.http(status, Self.errorMessage(data) ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
        return try Self.replyText(data)
    }

    /// The text of a Messages API reply. A refusal is reported as such, never read as an answer.
    static func replyText(_ data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IntelligenceError.badResponse("not JSON")
        }
        if (object["stop_reason"] as? String) == "refusal" {
            throw IntelligenceError.refused
        }
        let blocks = object["content"] as? [[String: Any]] ?? []
        let text = blocks.filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else {
            throw IntelligenceError.badResponse("stop_reason \(object["stop_reason"] as? String ?? "?") with no text")
        }
        return text
    }

    static func errorMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }
}

// MARK: - Local server (Ollama, LM Studio, mlx_lm.server, llama.cpp)

public struct LocalServerJudge: FileJudge {
    public let baseURL: URL
    public let model: String
    public let apiKey: String?
    public let onThisMac: Bool
    public var session: URLSession = .shared

    public init(baseURL: URL, model: String, apiKey: String? = nil, onThisMac: Bool) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.onThisMac = onThisMac
    }

    public var displayName: String {
        let server = LocalServerPreset.all.first { baseURL.absoluteString.hasPrefix($0.baseURL) }?.name ?? "Local model"
        return model.isEmpty ? server : "\(server) · \(model)"
    }

    public var staysOnDevice: Bool { onThisMac }

    public func judge(_ request: FileJudgementRequest) async throws -> FileJudgement {
        let text = try await chat(
            system: JudgementPrompt.system,
            user: JudgementPrompt.user(request),
            schema: JudgementPrompt.schema(fields: request.fields),
            name: "file_judgement"
        )
        return try JudgementPrompt.parse(text, request: request, answeredBy: displayName)
    }

    public func draftRule(description: String, folderNames: [String], destinationNames: [String]) async throws -> Data? {
        let text = try await chat(
            system: RuleDraftPrompt.system,
            user: RuleDraftPrompt.user(description: description, folderNames: folderNames, destinationNames: destinationNames),
            schema: RuleDraftPrompt.schema,
            name: "rule_draft"
        )
        return JSONText.firstObject(in: text).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
    }

    func chat(system: String, user: String, schema: [String: Any], name: String) async throws -> String {
        guard !model.isEmpty else {
            throw IntelligenceError.notConfigured("Choose a model for the local server in Settings.")
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        // Local models on a laptop can take a while for the first answer while they load.
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            // Servers that do not support schemas ignore this; the reply is still parsed for JSON.
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": name, "schema": schema, "strict": true] as [String: Any],
            ] as [String: Any],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .cannotFindHost {
            throw IntelligenceError.unavailable("Nothing answers at \(baseURL.absoluteString). Start the server, then try again.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String ?? $0["error"] as? String }
            throw IntelligenceError.http(status, message ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
        return try Self.replyText(data)
    }

    static func replyText(_ data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw IntelligenceError.badResponse("no choices[0].message.content")
        }
        return content
    }

    /// Model names the server offers (`GET /v1/models`), for the settings picker.
    public static func listModels(baseURL: URL, apiKey: String? = nil) async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.timeoutInterval = 5
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = object?["data"] as? [[String: Any]] ?? []
        return entries.compactMap { $0["id"] as? String }.sorted()
    }
}

// MARK: - Apple Intelligence (on-device)

public struct AppleOnDeviceJudge: FileJudge {
    public init() {}

    public var displayName: String { "Apple Intelligence" }
    public var staysOnDevice: Bool { true }

    /// Why the on-device model cannot be used, or nil when it can.
    public static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return "This Mac cannot run Apple Intelligence."
                case .appleIntelligenceNotEnabled: return "Turn on Apple Intelligence in System Settings."
                case .modelNotReady: return "Apple Intelligence is still downloading its model."
                @unknown default: return "Apple Intelligence is not available."
                }
            }
        }
        return "Apple Intelligence needs macOS 26."
        #else
        return "This build of Sift was made without Apple Intelligence."
        #endif
    }

    public func judge(_ request: FileJudgementRequest) async throws -> FileJudgement {
        let text = try await respond(system: JudgementPrompt.system, user: JudgementPrompt.user(request) + "\nReply with one JSON object with keys matches, reason, fields.")
        return try JudgementPrompt.parse(text, request: request, answeredBy: displayName)
    }

    public func draftRule(description: String, folderNames: [String], destinationNames: [String]) async throws -> Data? {
        let text = try await respond(
            system: RuleDraftPrompt.system,
            user: RuleDraftPrompt.user(description: description, folderNames: folderNames, destinationNames: destinationNames)
        )
        return JSONText.firstObject(in: text).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
    }

    private func respond(system: String, user: String) async throws -> String {
        if let reason = Self.unavailableReason {
            throw IntelligenceError.unavailable(reason)
        }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user, options: GenerationOptions(temperature: 0))
            return response.content
        }
        #endif
        throw IntelligenceError.unavailable("Apple Intelligence needs macOS 26.")
    }
}

// MARK: - Jev (yes/no only)

public struct JevJudge: FileJudge {
    public init() {}

    public var displayName: String { "Jev" }
    public var staysOnDevice: Bool { false }

    public func judge(_ request: FileJudgementRequest) async throws -> FileJudgement {
        let local = try await SiftJudge().judge(request)
        guard let check = request.check, !check.isEmpty else { return local }
        let state = "File name: \(request.fileName)\nOpening text: \(String(request.text.prefix(1_500)))"
        guard let scores = try await JevClient.askNouls(state: state, questions: ["fits": "Is this file \(check)?"]),
              let score = scores["fits"] else {
            throw IntelligenceError.notConfigured("Save a Jev key in Settings, or pick another reader.")
        }
        let fits = score >= 0.5
        return FileJudgement(
            matches: fits,
            reason: fits ? local.reason : "Jev: not \(check)",
            fields: local.fields,
            answeredBy: "Jev + Sift"
        )
    }
}

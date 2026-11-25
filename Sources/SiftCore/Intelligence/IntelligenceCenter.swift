import Foundation

/// The reader the person picked in Settings, and an honest line about where text goes.
@MainActor
public final class IntelligenceCenter: ObservableObject {
    @Published public var settings: IntelligenceSettings {
        didSet { settings.save(defaults: defaults) }
    }
    @Published public private(set) var claudeKeySaved: Bool
    @Published public private(set) var localModels: [String] = []
    @Published public private(set) var lastTestResult: String?

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = SiftRuntime.defaults) {
        self.defaults = defaults
        self.settings = IntelligenceSettings.load(defaults: defaults)
        self.claudeKeySaved = KeychainSecret.claudeAPIKey.isConfigured
    }

    public func saveClaudeKey(_ key: String) {
        KeychainSecret.claudeAPIKey.save(key)
        claudeKeySaved = KeychainSecret.claudeAPIKey.isConfigured
        if !claudeKeySaved, settings.provider == .claude {
            settings.provider = .sift
        }
    }

    /// The reader to use now. Falls back to Sift's own reading when the chosen one is not set up,
    /// so a rule never silently sends text somewhere the person did not choose.
    public func currentJudge() -> any FileJudge {
        switch settings.provider {
        case .sift:
            return SiftJudge()
        case .apple:
            return AppleOnDeviceJudge.unavailableReason == nil ? AppleOnDeviceJudge() : SiftJudge()
        case .localServer:
            guard let url = URL(string: settings.localServerURL), !settings.localModel.isEmpty else { return SiftJudge() }
            return LocalServerJudge(
                baseURL: url,
                model: settings.localModel,
                apiKey: KeychainSecret.localServerKey.load(),
                onThisMac: settings.localServerIsOnThisMac
            )
        case .claude:
            guard let key = KeychainSecret.claudeAPIKey.load(), !key.isEmpty else { return SiftJudge() }
            return ClaudeJudge(model: settings.claudeModel, apiKey: key)
        case .jev:
            return JevCredential.isConfigured ? JevJudge() : SiftJudge()
        }
    }

    /// Why the chosen reader is not the one in use, or nil.
    public var setupProblem: String? {
        switch settings.provider {
        case .sift: return nil
        case .apple: return AppleOnDeviceJudge.unavailableReason
        case .localServer:
            if URL(string: settings.localServerURL) == nil { return "The local server address is not a URL." }
            return settings.localModel.isEmpty ? tr("Pick a model for the local server.", "Choisissez un modèle pour le serveur.") : nil
        case .claude: return claudeKeySaved ? nil : tr("Save a Claude API key to use Claude.", "Enregistrez une clé API Claude pour utiliser Claude.")
        case .jev: return JevCredential.isConfigured ? nil : "Save a Jev key to use Jev."
        }
    }

    public struct Status: Equatable, Sendable {
        public var readerName: String
        public var staysOnDevice: Bool
        public var line: String
    }

    /// Shown next to every rule and in the menu bar.
    public var status: Status {
        let judge = currentJudge()
        let line: String
        if let problem = setupProblem {
            line = tr("\(problem) Until then Sift reads files itself, on this Mac.", "\(problem) D’ici là, Sift lit les fichiers lui-même, sur ce Mac.")
        } else if judge.staysOnDevice {
            line = tr("\(judge.displayName) reads files on this Mac. Nothing is sent.", "\(judge.displayName) lit les fichiers sur ce Mac. Rien n’est envoyé.")
        } else if settings.provider == .claude {
            line = tr("The start of each matching file’s text is sent to Anthropic (Claude). The file itself stays here.", "Le début du texte de chaque fichier concerné est envoyé à Anthropic (Claude). Le fichier reste ici.")
        } else if settings.provider == .localServer, let host = URL(string: settings.localServerURL)?.host {
            line = tr("The start of each matching file’s text is sent to \(host).", "Le début du texte de chaque fichier concerné est envoyé à \(host).")
        } else {
            line = tr("The start of each matching file’s text is sent to \(judge.displayName).", "Le début du texte de chaque fichier concerné est envoyé à \(judge.displayName).")
        }
        return Status(readerName: judge.displayName, staysOnDevice: judge.staysOnDevice, line: line)
    }

    public func refreshLocalModels() async {
        guard let url = URL(string: settings.localServerURL) else { localModels = []; return }
        do {
            localModels = try await LocalServerJudge.listModels(baseURL: url, apiKey: KeychainSecret.localServerKey.load())
            if settings.localModel.isEmpty, let first = localModels.first {
                settings.localModel = first
            }
        } catch {
            localModels = []
        }
    }

    /// One small request to prove the reader works.
    public func test() async {
        lastTestResult = "Testing…"
        let judge = currentJudge()
        let sample = FileJudgementRequest(
            fileName: "Invoice_88231.pdf",
            text: "Acme Corp\nInvoice 88231\nDate: 2026-11-03\nTotal due: 129.00 EUR",
            check: "an invoice or receipt",
            fields: ["vendor", "date", "amount"]
        )
        do {
            let result = try await judge.judge(sample)
            let values = result.fields.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            lastTestResult = "\(judge.displayName) answered: \(result.matches == true ? "an invoice" : "not an invoice"). \(values)"
        } catch {
            lastTestResult = "\(judge.displayName): \(error.localizedDescription)"
        }
    }
}

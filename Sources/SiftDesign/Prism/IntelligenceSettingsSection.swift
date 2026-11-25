import SiftCore
import SwiftUI

/// Settings › Who reads files: the reader folder rules use, and where text goes.
public struct IntelligenceSettingsSection: View {
    @ObservedObject var intelligence: IntelligenceCenter
    @State private var claudeKey = ""
    @State private var localKey = ""
    @State private var confirmRemoveKey = false

    public init(intelligence: IntelligenceCenter) {
        self.intelligence = intelligence
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(tr("Reader", "Lecteur"), selection: $intelligence.settings.provider) {
                ForEach(IntelligenceProviderKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Text(intelligence.settings.provider.summary)
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            switch intelligence.settings.provider {
            case .claude: claudeFields
            case .localServer: localFields
            case .apple:
                if let reason = AppleOnDeviceJudge.unavailableReason {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(PrismTheme.accentSecondary)
                }
            case .sift, .jev:
                EmptyView()
            }

            statusLine

            HStack {
                Button(tr("Test with a sample invoice", "Tester avec une facture exemple")) {
                    Task { await intelligence.test() }
                }
                .buttonStyle(.bordered)
                .prismClickable()
                if let result = intelligence.lastTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(PrismTheme.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .confirmationDialog(tr("Remove the Claude key?", "Retirer la clé Claude ?"), isPresented: $confirmRemoveKey) {
            Button(tr("Remove", "Retirer"), role: .destructive) { intelligence.saveClaudeKey("") }
        } message: {
            Text(tr("Rules that used Claude go back to Sift’s own reading on this Mac.", "Les règles qui utilisaient Claude reviennent à la lecture de Sift sur ce Mac."))
        }
    }

    private var statusLine: some View {
        let status = intelligence.status
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.staysOnDevice ? "lock.laptopcomputer" : "icloud.and.arrow.up")
                .foregroundStyle(status.staysOnDevice ? Color.green : PrismTheme.accentSecondary)
            Text(status.line)
                .font(.caption)
                .foregroundStyle(PrismTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var claudeFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField(intelligence.claudeKeySaved ? tr("Key saved in the keychain", "Clé enregistrée dans le trousseau") : tr("Anthropic API key (sk-ant-…)", "Clé API Anthropic (sk-ant-…)"), text: $claudeKey)
                    .textFieldStyle(.roundedBorder)
                Button(tr("Save", "Enregistrer")) {
                    intelligence.saveClaudeKey(claudeKey)
                    claudeKey = ""
                }
                .disabled(claudeKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if intelligence.claudeKeySaved {
                    Button(tr("Remove", "Retirer")) { confirmRemoveKey = true }
                }
            }
            HStack {
                Text(tr("Model", "Modèle")).font(.caption).foregroundStyle(PrismTheme.textSecondary)
                TextField(IntelligenceSettings.defaultClaudeModel, text: $intelligence.settings.claudeModel)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }
            Text(tr("Each matching file sends its name and up to 6,000 characters of its opening text. Get a key at console.anthropic.com. Usage is billed to your Anthropic account.", "Chaque fichier concerné envoie son nom et jusqu’à 6 000 caractères de son début. Clé sur console.anthropic.com. L’usage est facturé sur votre compte Anthropic."))
                .font(.caption2)
                .foregroundStyle(PrismTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu(tr("Preset", "Préréglage")) {
                    ForEach(LocalServerPreset.all) { preset in
                        Button("\(preset.name) — \(preset.baseURL)") {
                            intelligence.settings.localServerURL = preset.baseURL
                            Task { await intelligence.refreshLocalModels() }
                        }
                    }
                }
                .fixedSize()
                TextField("http://localhost:11434/v1", text: $intelligence.settings.localServerURL)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                if intelligence.localModels.isEmpty {
                    TextField(tr("Model name, e.g. llama3.2 or mlx-community/Qwen2.5-7B-Instruct-4bit", "Nom du modèle, ex. llama3.2 ou mlx-community/Qwen2.5-7B-Instruct-4bit"), text: $intelligence.settings.localModel)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker(tr("Model", "Modèle"), selection: $intelligence.settings.localModel) {
                        ForEach(intelligence.localModels, id: \.self) { Text($0).tag($0) }
                    }
                }
                Button(tr("Find models", "Chercher les modèles")) {
                    Task { await intelligence.refreshLocalModels() }
                }
            }
            HStack {
                SecureField(tr("API key (company servers usually need one)", "Clé API (souvent requise par un serveur d’entreprise)"), text: $localKey)
                    .textFieldStyle(.roundedBorder)
                Button(tr("Save", "Enregistrer")) {
                    KeychainSecret.localServerKey.save(localKey)
                    localKey = ""
                }
                .disabled(localKey.isEmpty)
            }
        }
        .task { await intelligence.refreshLocalModels() }
    }
}

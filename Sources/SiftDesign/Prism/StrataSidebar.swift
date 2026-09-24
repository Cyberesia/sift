import SiftCore
import SwiftUI

public struct StrataSidebar: View {
    @Binding var selectedPipeline: MediaPipeline
    let counts: [MediaPipeline: Int]
    let personCollections: [StratumCollectionRecord]
    let selectedPersonCollectionID: String?
    var onSelectPersonCollection: ((String?) -> Void)?
    var onActivate: (() -> Void)?

    public init(
        selectedPipeline: Binding<MediaPipeline>,
        counts: [MediaPipeline: Int],
        personCollections: [StratumCollectionRecord] = [],
        selectedPersonCollectionID: String? = nil,
        onSelectPersonCollection: ((String?) -> Void)? = nil,
        onActivate: (() -> Void)? = nil
    ) {
        _selectedPipeline = selectedPipeline
        self.counts = counts
        self.personCollections = personCollections
        self.selectedPersonCollectionID = selectedPersonCollectionID
        self.onSelectPersonCollection = onSelectPersonCollection
        self.onActivate = onActivate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text("Name faces and review suggestions in Review AI.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            ForEach(MediaPipeline.allCases) { pipeline in
                strataRow(pipeline) {
                    onSelectPersonCollection?(nil)
                }
            }

            if !namedPeople.isEmpty {
                Divider().opacity(0.35)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Named people")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("People you have named in Review AI.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                ForEach(namedPeople, id: \.id) { person in
                    personRow(person)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
        .prismGlass(cornerRadius: 28, padding: 0)
    }

    private var namedPeople: [StratumCollectionRecord] {
        personCollections.filter { collection in
            if let userTitle = collection.userTitle, !userTitle.isEmpty { return true }
            return !collection.title.hasPrefix("Person ")
        }
    }

    @ViewBuilder
    private func strataRow(_ pipeline: MediaPipeline, onSelect: @escaping () -> Void) -> some View {
        let isSelected = selectedPipeline == pipeline && selectedPersonCollectionID == nil
        Button {
            withAnimation(PrismMotion.quick) {
                selectedPipeline = pipeline
                onSelect()
                onActivate?()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pipeline.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 22)
                Text(pipeline.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
                Text("\(counts[pipeline] ?? 0)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PrismTheme.accentSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(PrismTheme.accent.opacity(0.45), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .prismClickable()
    }

    private func personRow(_ person: StratumCollectionRecord) -> some View {
        let isSelected = selectedPersonCollectionID == person.id
        return Button {
            withAnimation(PrismMotion.quick) {
                onSelectPersonCollection?(person.id)
                onActivate?()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PrismTheme.accent)
                Text(person.displayTitle)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text("\(person.assets?.count ?? 0)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(PrismTheme.accentSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(PrismTheme.accent.opacity(0.45), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .prismClickable()
    }
}

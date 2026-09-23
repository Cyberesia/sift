import Foundation

public enum SearchTermMatcher {
    /// Whole-word match. "cat" matches "cat" and "cat_01", not "application" or "location".
    public static func containsTerm(_ term: String, in text: String) -> Bool {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !text.isEmpty else { return false }
        let pattern = "(?i)(?<![\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: trimmed))(?![\\p{L}\\p{N}])"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

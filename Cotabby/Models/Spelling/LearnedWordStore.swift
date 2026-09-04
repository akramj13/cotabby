import Combine
import Foundation

/// Narrow persistence surface so the store can be unit-tested against an in-memory stand-in instead
/// of process-global `UserDefaults` (the same reasoning as `EmojiUsageDefaults`). `UserDefaults`
/// already satisfies every requirement, so production wiring is unchanged.
protocol LearnedWordDefaults: AnyObject {
    func stringArray(forKey defaultName: String) -> [String]?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: LearnedWordDefaults {}

/// File overview:
/// Words the user has taught Cotabby to leave alone. The only writer today is the automatic typo
/// fixer: when someone deletes a correction and types the original word again, that word lands here
/// and `CurrentWordSpellChecker` stops reporting it as a typo, so it is never corrected, offered a
/// correction, or hidden behind the typo gate again. Settings reads the same list so people can see
/// what was learned and forget it.
///
/// This is Cotabby's own list on purpose. `NSSpellChecker.learnWord` would add the word to the
/// user's system-wide dictionary, a global side effect on every other app that a background
/// correction heuristic has no business causing.
///
/// `@MainActor` because the writer is the main-actor coordinator between keystrokes and the reader
/// is the settings pane; `ObservableObject` so the pane refreshes when a word is learned. Matching
/// is case-insensitive because the retyped word may differ from the corrected one only in
/// capitalization, and the display keeps the form the user typed.
@MainActor
final class LearnedWordStore: ObservableObject {
    /// Oldest first, in the form the user typed.
    @Published private(set) var words: [String]

    private let defaults: LearnedWordDefaults
    /// Lowercased mirror of `words` so the typo gate's lookup stays O(1) per keystroke.
    private var normalizedWords: Set<String>

    private static let storageKey = "cotabbyLearnedWords"
    /// Generous for a hand-curated list while bounding what a runaway rejection loop could persist.
    static let capacity = 500

    init(defaults: LearnedWordDefaults = UserDefaults.standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.storageKey) ?? []
        words = stored
        normalizedWords = Set(stored.map(Self.normalized))
    }

    // See EmojiUsageStore: avoids the macOS 14 isolated-deinit back-deploy crash.
    nonisolated deinit {}

    func contains(_ word: String) -> Bool {
        let needle = Self.normalized(word)
        guard !needle.isEmpty else { return false }
        return normalizedWords.contains(needle)
    }

    /// Remembers `word` unless an equivalent entry exists. The oldest entries fall off past
    /// `capacity`.
    func learn(_ rawWord: String) {
        let word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !contains(word) else { return }
        words.append(word)
        normalizedWords.insert(Self.normalized(word))
        if words.count > Self.capacity {
            let dropped = words.prefix(words.count - Self.capacity)
            words.removeFirst(dropped.count)
            normalizedWords.subtract(dropped.map(Self.normalized))
        }
        persist()
    }

    func forget(_ word: String) {
        let needle = Self.normalized(word)
        guard normalizedWords.remove(needle) != nil else { return }
        words.removeAll { Self.normalized($0) == needle }
        persist()
    }

    func forgetAll() {
        guard !words.isEmpty else { return }
        words = []
        normalizedWords = []
        persist()
    }

    private func persist() {
        if words.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(words, forKey: Self.storageKey)
        }
    }

    private static func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

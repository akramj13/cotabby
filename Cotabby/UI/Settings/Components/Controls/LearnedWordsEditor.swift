import SwiftUI

/// File overview:
/// Settings list for `LearnedWordStore`: the words Cotabby stopped correcting because the user
/// undid an automatic fix and typed the word again. Each row forgets one word and "Forget All"
/// clears the list, after which Cotabby may correct those words again. Rows are sorted
/// alphabetically because this is a find-and-remove surface; the store itself keeps insertion
/// order so its capacity bound drops the oldest entries.
///
/// The enclosing pane supplies the section title and the explanatory caption (which also carries
/// the search anchor), so this view renders only the rows, mirroring how `AppsPaneView` lays out
/// its removable app lists.
struct LearnedWordsEditor: View {
    @ObservedObject var learnedWordStore: LearnedWordStore

    private var sortedWords: [String] {
        learnedWordStore.words.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        if sortedWords.isEmpty {
            Text("No learned words yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            ForEach(sortedWords, id: \.self) { word in
                learnedWordRow(word)
            }

            Button("Forget All") {
                learnedWordStore.forgetAll()
            }
        }
    }

    private func learnedWordRow(_ word: String) -> some View {
        HStack(spacing: 12) {
            Text(word)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            Button {
                learnedWordStore.forget(word)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Forget “\(word)” so Cotabby can correct it again")
            .accessibilityLabel("Forget \(word)")
        }
    }
}

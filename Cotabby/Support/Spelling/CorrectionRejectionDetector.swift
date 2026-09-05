import Foundation

/// File overview:
/// Pure rule that recognizes a user rejecting an automatic typo fix. `applyAutomaticCorrection`
/// replaces a just-finished word after Space; when the person then deletes the replacement and
/// types the original word again, correcting it a second time is exactly the loop this rule ends.
///
/// Why a record instead of "the same word twice": the same misspelling can legitimately recur in
/// one document (a habitual typo), and correcting it again is the feature working. The signal that
/// separates rejection from recurrence is that the *earlier correction is gone*: the text before
/// the caret no longer contains the replacement anywhere, and the original word is back at the
/// caret. Checking for the replacement's absence rather than comparing a saved prefix keeps the
/// rule correct when the AX text window slides or the user edits earlier text, at the cost of
/// missing a rejection in the rare document that also uses the replacement word legitimately.

/// What one automatic correction did, captured right after it was applied.
nonisolated struct AppliedCorrectionRecord: Equatable, Sendable {
    /// `focusedInputIdentityKey` of the field; a retype in another field is a separate decision.
    let fieldIdentityKey: UInt64
    /// The word as the user typed it, for example `chatgpt`.
    let typoWord: String
    /// What Cotabby replaced it with, for example `catgut`.
    let correctedWord: String
}

nonisolated enum CorrectionRejectionDetector {
    /// True when `completedWord`, just finished at the caret in `fieldIdentityKey`, is the recorded
    /// typo typed again while the recorded replacement no longer appears anywhere before the caret.
    /// Case-insensitive on both words so `ChatGPT` after a lowercase fix still counts; the caller
    /// learns the retyped form.
    static func isRejection(
        of record: AppliedCorrectionRecord,
        fieldIdentityKey: UInt64,
        precedingText: String,
        completedWord: String
    ) -> Bool {
        guard record.fieldIdentityKey == fieldIdentityKey,
              completedWord.caseInsensitiveCompare(record.typoWord) == .orderedSame
        else { return false }
        return precedingText.range(of: record.correctedWord, options: .caseInsensitive) == nil
    }
}

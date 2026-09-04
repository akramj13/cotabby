import XCTest
@testable import Cotabby

/// The rejection rule has one job: tell "the user undid this fix and typed the word again" apart
/// from "the user made the same typo again". The former ends the correction loop, the latter is the
/// feature working, so most cases here are the ones that must NOT count as rejections.
final class CorrectionRejectionDetectorTests: XCTestCase {
    private let record = AppliedCorrectionRecord(
        fieldIdentityKey: 42,
        typoWord: "chatgpt",
        correctedWord: "catgut"
    )

    func testRetypingTheWordAfterRemovingTheFixIsARejection() {
        XCTAssertTrue(
            CorrectionRejectionDetector.isRejection(
                of: record,
                fieldIdentityKey: 42,
                precedingText: "I asked chatgpt ",
                completedWord: "chatgpt"
            )
        )
    }

    /// The earlier replacement is still in the text, so this is the same typo recurring, and
    /// correcting it again is correct behavior.
    func testRepeatingTheTypoWhileTheFixRemainsIsNotARejection() {
        XCTAssertFalse(
            CorrectionRejectionDetector.isRejection(
                of: record,
                fieldIdentityKey: 42,
                precedingText: "I asked catgut and then chatgpt ",
                completedWord: "chatgpt"
            )
        )
    }

    func testAnotherFieldIsASeparateDecision() {
        XCTAssertFalse(
            CorrectionRejectionDetector.isRejection(
                of: record,
                fieldIdentityKey: 7,
                precedingText: "I asked chatgpt ",
                completedWord: "chatgpt"
            )
        )
    }

    func testADifferentWordIsNotARejection() {
        XCTAssertFalse(
            CorrectionRejectionDetector.isRejection(
                of: record,
                fieldIdentityKey: 42,
                precedingText: "I asked chatgtp ",
                completedWord: "chatgtp"
            )
        )
    }

    /// Capitalization differences on either side must not defeat the rule: the retyped word may be
    /// recased, and a recased replacement still counts as "the fix is in place".
    func testMatchingIsCaseInsensitiveOnBothWords() {
        XCTAssertTrue(
            CorrectionRejectionDetector.isRejection(
                of: record,
                fieldIdentityKey: 42,
                precedingText: "I asked ChatGPT ",
                completedWord: "ChatGPT"
            )
        )
        XCTAssertFalse(
            CorrectionRejectionDetector.isRejection(
                of: record,
                fieldIdentityKey: 42,
                precedingText: "Catgut string. I asked chatgpt ",
                completedWord: "chatgpt"
            )
        )
    }
}

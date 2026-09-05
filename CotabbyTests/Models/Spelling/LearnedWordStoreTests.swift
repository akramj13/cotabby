import XCTest
@testable import Cotabby

/// Persistence and matching rules for the learned-word list. The class is intentionally not
/// `@MainActor` (an `@MainActor` XCTestCase subclass crashes the app-hosted runner); main-actor work
/// runs inside `runOnMainActor`, and storage goes through an in-memory defaults stand-in.
final class LearnedWordStoreTests: XCTestCase {
    func test_learnIsCaseInsensitiveAndKeepsTheTypedForm() {
        runOnMainActor {
            let sut = LearnedWordStore(defaults: InMemoryLearnedWordDefaults())
            sut.learn("ChatGPT")
            sut.learn("chatgpt")

            XCTAssertEqual(sut.words, ["ChatGPT"])
            XCTAssertTrue(sut.contains("chatgpt"))
            XCTAssertTrue(sut.contains("CHATGPT"))
            XCTAssertFalse(sut.contains("catgut"))
        }
    }

    func test_blankInputIsIgnored() {
        runOnMainActor {
            let sut = LearnedWordStore(defaults: InMemoryLearnedWordDefaults())
            sut.learn("   ")
            XCTAssertTrue(sut.words.isEmpty)
            XCTAssertFalse(sut.contains(""))
        }
    }

    func test_wordsSurviveARelaunchThroughTheSameDefaults() {
        runOnMainActor {
            let defaults = InMemoryLearnedWordDefaults()
            LearnedWordStore(defaults: defaults).learn("chatgpt")

            let relaunched = LearnedWordStore(defaults: defaults)
            XCTAssertTrue(relaunched.contains("chatgpt"))
            XCTAssertEqual(relaunched.words, ["chatgpt"])
        }
    }

    func test_forgetRemovesOneWordAndForgetAllClearsTheStoredValue() {
        runOnMainActor {
            let defaults = InMemoryLearnedWordDefaults()
            let sut = LearnedWordStore(defaults: defaults)
            sut.learn("chatgpt")
            sut.learn("kubectl")

            sut.forget("CHATGPT")
            XCTAssertEqual(sut.words, ["kubectl"])
            XCTAssertFalse(sut.contains("chatgpt"))

            sut.forgetAll()
            XCTAssertTrue(sut.words.isEmpty)
            XCTAssertTrue(defaults.storage.isEmpty, "An empty list should not leave a stale key behind")
        }
    }

    func test_oldestWordsFallOffPastCapacity() {
        runOnMainActor {
            let sut = LearnedWordStore(defaults: InMemoryLearnedWordDefaults())
            for index in 0...LearnedWordStore.capacity {
                sut.learn("word\(index)")
            }

            XCTAssertEqual(sut.words.count, LearnedWordStore.capacity)
            XCTAssertFalse(sut.contains("word0"))
            XCTAssertTrue(sut.contains("word\(LearnedWordStore.capacity)"))
        }
    }
}

private func runOnMainActor<Result>(
    _ body: @MainActor () throws -> Result
) rethrows -> Result {
    if Thread.isMainThread {
        return try MainActor.assumeIsolated(body)
    }

    return try DispatchQueue.main.sync {
        try MainActor.assumeIsolated(body)
    }
}

import Foundation
@testable import Cotabby

/// In-memory stand-in for the `LearnedWordDefaults` persistence surface so learned-word tests never
/// touch process-global `UserDefaults`, which is shared across the app-hosted test run.
final class InMemoryLearnedWordDefaults: LearnedWordDefaults {
    private(set) var storage: [String: [String]] = [:]

    func stringArray(forKey defaultName: String) -> [String]? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value as? [String] }
    func removeObject(forKey defaultName: String) { storage[defaultName] = nil }
}

import Foundation
import NaturalLanguage

/// Related-word matching for Search's commit text, used only when no deployment
/// contains every typed word. "analytics fix" then finds "Repair Web Analytics":
/// each typed word may match its own word forms, a curated developer synonym,
/// or a near neighbour from the on-device English word embedding.
struct CommitTextMatcher: Sendable {
    static let neighborCount = 5
    /// Cosine distance; below 1 the words point the same way.
    static let maximumNeighborDistance = 0.9

    var neighbors: @Sendable (String) -> [String]

    static let onDevice = CommitTextMatcher(neighbors: EnglishWordNeighbors.lookup)
    /// Word forms and synonyms only, for deterministic tests.
    static let curated = CommitTextMatcher(neighbors: { _ in [] })

    /// One set of accepted stems per meaningful typed word.
    func expansions(for text: String) -> [Set<String>] {
        Self.words(in: text).filter { !Self.stopWords.contains($0) }.map { word in
            let stem = Self.stem(word)
            var accepted: Set<String> = [stem]
            for group in Self.synonymStems where group.contains(stem) { accepted.formUnion(group) }
            for neighbor in neighbors(word) { accepted.insert(Self.stem(neighbor)) }
            return accepted
        }
    }

    /// Every expansion must meet at least one word of `fields`.
    func matches(_ expansions: [Set<String>], in fields: String) -> Bool {
        guard !expansions.isEmpty else { return false }
        let stems = Set(Self.words(in: fields).map(Self.stem))
        return expansions.allSatisfy { !$0.isDisjoint(with: stems) }
    }

    static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// A small suffix stripper, enough to line up "fixes", "fixed" and "fixing"
    /// or "update" and "updated". Not a linguistic stemmer.
    static func stem(_ word: String) -> String {
        var w = word.lowercased()
        guard w.count > 3, w.allSatisfy(\.isLetter) else { return w }
        if w.hasSuffix("ies"), w.count > 4 {
            w = String(w.dropLast(3)) + "y"
        } else if w.hasSuffix("es"), ["s", "x", "z", "ch", "sh"].contains(where: { w.dropLast(2).hasSuffix($0) }) {
            w = String(w.dropLast(2))
        } else if w.hasSuffix("s"), !w.hasSuffix("ss"), !w.hasSuffix("us"), !w.hasSuffix("is") {
            w = String(w.dropLast())
        }
        if w.hasSuffix("ing"), w.count > 5 {
            w = String(w.dropLast(3))
        } else if w.hasSuffix("ed"), w.count > 4 {
            w = String(w.dropLast(2))
        }
        // "dropped" and "bumping" leave a doubled final consonant.
        if w.count > 3, let last = w.last, w.dropLast().last == last, !"lsz".contains(last) { w.removeLast() }
        if w.count > 3, w.hasSuffix("e") { w.removeLast() }
        return w
    }

    static let stopWords: Set<String> = ["a", "an", "the", "to", "of", "for", "in", "on", "and", "with", "my", "our", "that", "this"]

    /// Words developers use interchangeably in commit messages.
    static let synonymStems: [Set<String>] = [
        ["fix", "repair", "patch", "bugfix", "hotfix", "resolve", "correct"],
        ["add", "introduce", "create", "implement", "new"],
        ["remove", "delete", "drop", "strip"],
        ["update", "bump", "upgrade", "refresh"],
        ["refactor", "cleanup", "clean", "tidy", "simplify", "restructure"],
        ["doc", "docs", "documentation", "readme"],
        ["test", "tests", "spec"],
        ["style", "styling", "css", "theme"],
        ["dependency", "dependencies", "deps", "package"],
        ["revert", "rollback", "undo"],
        ["config", "configuration", "settings"],
        ["perf", "performance", "speed", "faster", "optimize", "optimise"],
        ["bug", "defect", "issue"],
        ["analytics", "tracking", "telemetry", "metrics"],
        ["auth", "authentication", "login", "signin"],
        ["image", "images", "img", "picture", "photo"],
        ["nav", "navigation", "menu"],
        ["translation", "localization", "localisation", "i18n", "l10n"],
        ["blog", "post", "article"],
        ["typo", "spelling"],
    ].map { Set($0.map(stem)) }
}

/// The system's English word embedding, loaded once on first related search.
enum EnglishWordNeighbors {
    nonisolated(unsafe) private static let embedding = NLEmbedding.wordEmbedding(for: .english)
    private static let lock = NSLock()

    static func lookup(_ word: String) -> [String] {
        guard word.count > 2, word.allSatisfy(\.isLetter) else { return [] }
        lock.lock()
        defer { lock.unlock() }
        guard let embedding else { return [] }
        return embedding.neighbors(for: word.lowercased(), maximumCount: CommitTextMatcher.neighborCount, distanceType: .cosine)
            .filter { $0.1 <= CommitTextMatcher.maximumNeighborDistance }
            .map(\.0)
    }
}

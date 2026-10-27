import Foundation

/// In-memory reuse only for identical, bounded evidence in the same account/site.
struct BriefReuseCache {
    struct Key: Hashable {
        var accountID: String
        var teamID: String?
        var projectID: String
        var prompt: String
    }
    private struct Entry { var key: Key; var text: String; var date: Date }
    private var entries: [Entry] = []
    static let lifetime: TimeInterval = 300
    static let capacity = 6

    func text(for key: Key, now: Date = Date()) -> String? {
        guard let entry = entries.first(where: { $0.key == key }),
              (0..<Self.lifetime).contains(now.timeIntervalSince(entry.date)) else { return nil }
        return entry.text
    }

    mutating func insert(_ text: String, for key: Key, now: Date = Date()) {
        guard key.prompt.utf8.count <= BriefModelPolicy.maximumInputBytes + 64,
              BriefModelPolicy.accept(text) != nil else { return }
        entries.removeAll { $0.key == key || now.timeIntervalSince($0.date) >= Self.lifetime }
        entries.insert(.init(key: key, text: text, date: now), at: 0)
        entries = Array(entries.prefix(Self.capacity))
    }

    mutating func clear() { entries = [] }
}

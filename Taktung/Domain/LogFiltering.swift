import Foundation

struct IndexedBuildLogLine: Identifiable {
    var id: Int
    var line: BuildLogLine
}

func isErrorLikeBuildLine(_ line: BuildLogLine) -> Bool {
    line.type == "stderr" || line.text.localizedCaseInsensitiveContains("error") || line.text.localizedCaseInsensitiveContains("failed")
}

func filterBuildLogs(_ lines: [BuildLogLine], query: String, errorsOnly: Bool) -> [IndexedBuildLogLine] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return lines.enumerated().compactMap { index, line in
        guard (!errorsOnly || isErrorLikeBuildLine(line)), query.isEmpty || line.text.localizedCaseInsensitiveContains(query) else { return nil }
        return IndexedBuildLogLine(id: index, line: line)
    }
}

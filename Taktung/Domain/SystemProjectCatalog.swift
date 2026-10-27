import Foundation

/// A shared catalog for system surfaces. No request is made while resolving names.
func widgetAccountContext(store: WidgetSnapshotStore = WidgetSnapshotStore()) -> WidgetAccountContext? {
    if store.token() != nil { return store.load() }
    #if DEBUG
    return store.load(source: .demo)
    #else
    return nil
    #endif
}

func systemProjects(in context: WidgetAccountContext?, matching query: String? = nil) -> [WidgetAccountContext.Project] {
    let query = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (context?.projects ?? []).filter {
        query.isEmpty || $0.name.localizedStandardContains(query)
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

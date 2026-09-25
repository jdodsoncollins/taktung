import SwiftUI

struct SitePickerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let ranked = rankSites(session.projects, query: query)
        List {
            Section {
                ForEach(ranked) { project in
                    SiteRowView(project: project, selected: session.selectedProjectId == project.id) {
                        Task {
                            await session.selectProject(project.id)
                            dismiss()
                        }
                    }
                    .listRowBackground(Palette.surface)
                    .listRowSeparatorTint(Palette.separator)
                }
            } header: {
                SectionLabel(text: query.trimmingCharacters(in: .whitespaces).isEmpty ? "Attention first" : "Matches")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .taktCanvas()
        .searchable(text: $query, prompt: "Filter sites")
        .navigationTitle("Sites")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .accessibilityIdentifier(AccessibilityIDs.sitePicker)
    }
}

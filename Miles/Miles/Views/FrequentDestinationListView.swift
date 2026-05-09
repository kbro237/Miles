import SwiftUI
import SwiftData

struct FrequentDestinationListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FrequentDestination.name) private var destinations: [FrequentDestination]

    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(destinations) { dest in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dest.name)
                            .font(.body)
                        Text(dest.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(destinations[index])
                    }
                }
            }
            .navigationTitle("Destinations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingForm = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingForm) {
                FrequentDestinationFormView()
            }
        }
    }
}

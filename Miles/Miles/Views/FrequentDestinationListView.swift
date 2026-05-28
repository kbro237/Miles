import SwiftUI
import SwiftData

struct FrequentDestinationListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FrequentDestination.name) private var destinations: [FrequentDestination]
    @AppStorage("defaultOrigin") private var defaultOrigin: String = ""

    @State private var showingForm = false

    var body: some View {
#if os(macOS)
        List {
            content
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
#else
        NavigationStack {
            List {
                content
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
#endif
    }

    @ViewBuilder
    private var content: some View {
        Section {
                    if !defaultOrigin.isEmpty {
                        HStack {
                            Image(systemName: "pin.circle.fill")
                                .foregroundStyle(.tint)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Default Starting Place")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(defaultOrigin)
                                    .font(.body)
                            }
                            Spacer()
                            Button {
                                defaultOrigin = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack {
                            Image(systemName: "pin.slash")
                                .foregroundStyle(.secondary)
                            Text("No default starting place set")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Default Starting Place")
                } footer: {
                    Text("Tap a destination below to set it as your default origin for new trips.")
                }

                Section("Destinations") {
                    ForEach(destinations) { dest in
                        Button {
                            defaultOrigin = dest.address
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dest.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(dest.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if defaultOrigin == dest.address {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
#if os(macOS)
                        .contextMenu {
                            Button("Delete") {
                                if defaultOrigin == dest.address {
                                    defaultOrigin = ""
                                }
                                context.delete(dest)
                            }
                        }
#endif
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if defaultOrigin == destinations[index].address {
                                defaultOrigin = ""
                            }
                            context.delete(destinations[index])
                        }
                    }
                }
            }
    }

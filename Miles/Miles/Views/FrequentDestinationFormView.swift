import SwiftUI
import SwiftData
import MapKit

struct FrequentDestinationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var destinations: [FrequentDestination]

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var showingDuplicateAlert = false
    @State private var searchService = AddressSearchService()
    @State private var didSelect = false
    @FocusState private var isFocused: Bool

    var body: some View {
#if os(macOS)
        Form {
            content
        }
        .navigationTitle("New Destination")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveDestination()
                }
                .disabled(name.isEmpty || address.isEmpty)
            }
        }
        .alert("Duplicate Name", isPresented: $showingDuplicateAlert) {
            Button("OK") {}
        } message: {
            Text("A destination named \"\(name)\" already exists.")
        }
#else
        NavigationStack {
            Form {
                content
            }
            .navigationTitle("New Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDestination()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
            .alert("Duplicate Name", isPresented: $showingDuplicateAlert) {
                Button("OK") {}
            } message: {
                Text("A destination named \"\(name)\" already exists.")
            }
        }
#endif
    }

    private func saveDestination() {
        if destinations.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            showingDuplicateAlert = true
            return
        }
        let dest = FrequentDestination(name: name, address: address)
        context.insert(dest)
        dismiss()
    }

    @ViewBuilder
    private var content: some View {
        TextField("Name", text: $name)

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($isFocused)
                        .onChange(of: address) { _, newValue in
                            guard !didSelect else {
                                didSelect = false
                                return
                            }
                            searchService.search(newValue)
                        }

                    if !address.isEmpty && !searchService.results.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(searchService.results, id: \.self) { completion in
                                Button(action: {
                                    didSelect = true
                                    searchService.results = []
                                    isFocused = false
                                    address = "\(completion.title), \(completion.subtitle)"
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
#if os(iOS)
                        .background(Color(.systemBackground))
#else
                        .background(Color(nsColor: .windowBackgroundColor))
#endif
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
#if os(iOS)
                                .stroke(Color(.separator), lineWidth: 1)
#else
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
#endif
                        )
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .padding(.top, 4)
                    }
                }
            }
    }

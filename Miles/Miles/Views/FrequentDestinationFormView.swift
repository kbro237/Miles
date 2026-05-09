import SwiftUI
import SwiftData

struct FrequentDestinationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var destinations: [FrequentDestination]

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var showingDuplicateAlert = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Address", text: $address, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle("New Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if destinations.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                            showingDuplicateAlert = true
                            return
                        }
                        let dest = FrequentDestination(name: name, address: address)
                        context.insert(dest)
                        dismiss()
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
    }
}

import SwiftUI
import SwiftData

struct FrequentDestinationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var address: String = ""

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
                        let dest = FrequentDestination(name: name, address: address)
                        context.insert(dest)
                        dismiss()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
}

import SwiftUI

struct QuarterDetailView: View {
    let quarter: Quarter
    let trips: [Trip]
    @Binding var isPaid: Bool

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Quarter", value: quarter.displayString)
                LabeledContent("Total Trips", value: "\(trips.count)")
                LabeledContent("Total Miles", value: "\(quarter.totalMiles(for: trips).formatted(.number.precision(.fractionLength(1))))")
                LabeledContent("Total Reimbursement", value: quarter.totalReimbursement(for: trips), format: .currency(code: "USD"))

                Toggle("Paid", isOn: $isPaid)
            }

            Section("Export") {
                Button("Export as CSV") { shareCSV() }
                Button("Export as Markdown") { shareMarkdown() }
                Button("Export as PDF") { sharePDF() }
            }

            Section("Trips") {
                ForEach(trips.sorted(by: { $0.date > $1.date })) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripRowView(trip: trip)
                    }
                }
            }
        }
        .navigationTitle(quarter.displayString)
    }

    private func shareCSV() {
        let csv = CSVExporter.export(quarter: quarter, trips: trips)
        share(text: csv, filename: "\(quarter.id)-mileage.csv")
    }

    private func shareMarkdown() {
        let md = MarkdownExporter.export(quarter: quarter, trips: trips)
        share(text: md, filename: "\(quarter.id)-mileage.md")
    }

    private func sharePDF() {
        guard let data = PDFExporter.export(quarter: quarter, trips: trips) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(quarter.id)-mileage.pdf")
        try? data.write(to: url)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av)
    }

    private func share(text: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av)
    }

    private func present(_ av: UIActivityViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(av, animated: true)
    }
}

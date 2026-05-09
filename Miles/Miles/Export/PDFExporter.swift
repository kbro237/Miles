import SwiftUI
import PDFKit

struct PDFExporter {
    static func export(quarter: Quarter, trips: [Trip]) -> Data? {
        let summary = PDFSummaryView(quarter: quarter, trips: trips)
        let hosting = UIHostingController(rootView: summary)
        let size = CGSize(width: 612, height: 792)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.backgroundColor = .white

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            hosting.view.layer.render(in: ctx.cgContext)
        }
    }
}

struct PDFSummaryView: View {
    let quarter: Quarter
    let trips: [Trip]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mileage Report — \(quarter.displayString)")
                .font(.title)
                .padding(.bottom, 8)

            let totalMiles = quarter.totalMiles(for: trips)
            let totalReimbursement = quarter.totalReimbursement(for: trips)

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Miles:")
                        .font(.headline)
                    Text("\(String(format: "%.1f", totalMiles))")
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Total Reimbursement:")
                        .font(.headline)
                    Text("$\(String(format: "%.2f", totalReimbursement))")
                }
            }
            .padding(.bottom, 8)

            Divider()

            ForEach(trips.sorted(by: { $0.date < $1.date })) { trip in
                HStack {
                    Text(trip.date.formatted(date: .numeric, time: .omitted))
                        .frame(width: 80, alignment: .leading)
                        .font(.caption)
                    Text(trip.originAddress)
                        .font(.caption)
                        .lineLimit(1)
                    Text("→")
                        .font(.caption)
                    Text(trip.destinationAddress)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(String(format: "%.1f", trip.effectiveDistanceRounded)) mi")
                        .font(.caption)
                        .frame(width: 50, alignment: .trailing)
                    Text("$\(String(format: "%.2f", trip.reimbursementTotal))")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                }
                Divider()
            }
        }
        .padding(40)
    }
}

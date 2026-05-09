import SwiftUI

struct PDFExporter {
    @MainActor
    static func export(quarter: Quarter, trips: [Trip]) -> Data? {
        let size = CGSize(width: 612, height: 792)

        let rendered = PDFSummaryView(quarter: quarter, trips: trips)
        let imageRenderer = ImageRenderer(content: rendered)
        imageRenderer.scale = 2.0

        guard let image = imageRenderer.uiImage else { return nil }

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        return pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct PDFSummaryView: View {
    let quarter: Quarter
    let trips: [Trip]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mileage Report — \(quarter.displayString)")
                .font(.system(size: 16, weight: .bold))
                .padding(.bottom, 4)

            let totalMiles = quarter.totalMiles(for: trips)
            let totalReimbursement = quarter.totalReimbursement(for: trips)

            HStack {
                Text("Total Miles: \(String(format: "%.1f", totalMiles))")
                    .font(.system(size: 10))
                Spacer()
                Text("Total Reimbursement: $\(String(format: "%.2f", totalReimbursement))")
                    .font(.system(size: 10))
            }
            .padding(.bottom, 4)

            Divider()

            ForEach(trips.sorted(by: { $0.date < $1.date })) { trip in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 4) {
                        Text(trip.date.formatted(date: .numeric, time: .omitted))
                            .font(.system(size: 9))
                            .frame(width: 72, alignment: .leading)

                        VStack(alignment: .leading, spacing: 1) {
                            if !trip.purpose.isEmpty {
                                Text(trip.purpose)
                                    .font(.system(size: 9, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("\(trip.originAddress)")
                                .font(.system(size: 9))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(trip.isRoundTrip ? "↔" : "→") \(trip.destinationAddress)")
                                .font(.system(size: 9))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(trip.rateCentsPerMile)¢")
                                .font(.system(size: 9))
                            Text(String(format: "%.1f mi", trip.effectiveDistanceRounded))
                                .font(.system(size: 9))
                            Text("$\(String(format: "%.2f", trip.reimbursementTotal))")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(width: 60)
                    }
                    Divider()
                }
            }
        }
        .padding(24)
        .frame(width: 612, height: 792, alignment: .topLeading)
    }
}

import SwiftUI
#if os(macOS)
import PDFKit
#endif

struct PDFExporter {
    private static let tripsPerPage = 12

    @MainActor
    static func export(quarter: Quarter, trips: [Trip]) -> Data? {
        let pageSize = CGSize(width: 612, height: 792)
        let scale: CGFloat = 0.9
        let contentSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        let offsetX = (pageSize.width - contentSize.width) / 2
        let offsetY = (pageSize.height - contentSize.height) / 2
        let contentRect = CGRect(x: offsetX, y: offsetY, width: contentSize.width, height: contentSize.height)
        let sorted = trips.sorted(by: { $0.date < $1.date })
        let totalMiles = quarter.totalMiles(for: sorted)
        let totalReimbursement = quarter.totalReimbursement(for: sorted)
        let pages: [[Trip]] = {
            if sorted.isEmpty { return [[]] }
            return stride(from: 0, to: sorted.count, by: tripsPerPage).map {
                Array(sorted[$0..<min($0 + tripsPerPage, sorted.count)])
            }
        }()
        let totalPages = pages.count

#if os(macOS)
        let doc = PDFDocument()
        for (i, pageTrips) in pages.enumerated() {
            let view = PDFSummaryView(
                quarter: quarter,
                trips: pageTrips,
                totalMiles: totalMiles,
                totalReimbursement: totalReimbursement,
                page: i + 1,
                totalPages: totalPages
            )
            .frame(width: contentSize.width, height: contentSize.height)
            .id(UUID())
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2.0
            guard let cgImage = renderer.cgImage else { continue }
            let contentImage = NSImage(cgImage: cgImage, size: contentSize)

            let pageImage = NSImage(size: pageSize)
            pageImage.lockFocus()
            contentImage.draw(in: contentRect)
            pageImage.unlockFocus()

            guard let pdfPage = PDFPage(image: pageImage) else { continue }
            doc.insert(pdfPage, at: doc.pageCount)
        }
        return doc.dataRepresentation()
#else
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return pdfRenderer.pdfData { ctx in
            for (i, pageTrips) in pages.enumerated() {
                let view = PDFSummaryView(
                    quarter: quarter,
                    trips: pageTrips,
                    totalMiles: totalMiles,
                    totalReimbursement: totalReimbursement,
                    page: i + 1,
                    totalPages: totalPages
                )
                .frame(width: contentSize.width, height: contentSize.height)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2.0
                guard let image = renderer.uiImage else { continue }
                ctx.beginPage()
                image.draw(in: contentRect)
            }
        }
#endif
    }
}

struct PDFSummaryView: View {
    let quarter: Quarter
    let trips: [Trip]
    var totalMiles: Double = 0
    var totalReimbursement: Double = 0
    var page: Int = 1
    var totalPages: Int = 1

    private var isFirstPage: Bool { page == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isFirstPage {
                Text("Mileage Report — \(quarter.displayString)")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.bottom, 4)

                HStack {
                    Text("Total Miles: \(String(format: "%.1f", totalMiles))")
                        .font(.system(size: 10))
                    Spacer()
                    Text("Total Reimbursement: $\(String(format: "%.2f", totalReimbursement))")
                        .font(.system(size: 10))
                }
                .padding(.bottom, 4)
            } else {
                HStack {
                    Text("\(quarter.displayString) (continued)")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("Page \(page) of \(totalPages)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }

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
                            Text("\(String(format: "%.1f", trip.rateCentsPerMile))¢")
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

            if totalPages > 1 && isFirstPage {
                Spacer()
                Text("Page 1 of \(totalPages)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

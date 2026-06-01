import PDFKit
import UIKit

enum PDFExporter {
    static func generate(financing: Financing) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "CarLoan",
            kCGPDFContextAuthor: "CarLoan App"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // Title
            let title = financing.carName
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 30

            // Subtitle
            let subtitle = financing.bank
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]
            subtitle.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 24

            // Summary
            let paid = financing.installments.filter { $0.payment != nil }
            let totalPaid = paid.reduce(0.0) { $0 + ($1.payment?.paidAmount ?? 0) }
            let remaining = financing.installments.filter { $0.payment == nil }
            let totalRemaining = remaining.reduce(0.0) { $0 + $1.amount }

            let summaryLines = [
                "\(String(localized: "pdf.installments")): \(paid.count)/\(financing.totalInstallments)",
                "\(String(localized: "pdf.paid")): \(formatCurrency(totalPaid))",
                "\(String(localized: "pdf.remaining")): \(formatCurrency(totalRemaining))"
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            for line in summaryLines {
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                y += 18
            }
            y += 10

            // Table header
            let colX: [CGFloat] = [margin, 80, 180, 270, 360, 460]
            let headers = ["#", String(localized: "pdf.due"), String(localized: "pdf.amount"),
                           String(localized: "pdf.principal"), String(localized: "pdf.interest"),
                           String(localized: "pdf.status")]
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            for (i, h) in headers.enumerated() {
                h.draw(at: CGPoint(x: colX[i], y: y), withAttributes: headerAttrs)
            }
            y += 16

            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.black
            ]
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .none

            for inst in financing.installments.sorted(by: { $0.number < $1.number }) {
                if y > pageHeight - margin {
                    ctx.beginPage()
                    y = margin
                }
                let status = inst.status
                let cols = [
                    "\(inst.number)",
                    df.string(from: inst.dueDate),
                    formatCurrency(inst.amount),
                    formatCurrency(inst.principalAmount),
                    formatCurrency(inst.interestAmount),
                    String(localized: String.LocalizationValue(status.labelKey))
                ]
                for (i, col) in cols.enumerated() {
                    col.draw(at: CGPoint(x: colX[i], y: y), withAttributes: rowAttrs)
                }
                y += 14
            }

            // Footer
            let dateStr = df.string(from: Date())
            let footer = "\(String(localized: "pdf.generated")): \(dateStr)"
            footer.draw(
                at: CGPoint(x: margin, y: pageHeight - margin),
                withAttributes: subtitleAttrs
            )
        }

        return data
    }

    private static func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale.current
        return fmt.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

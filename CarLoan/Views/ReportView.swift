import SwiftUI

struct ReportView: View {
    let financing: Financing
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var exportFormat: ExportFormat?

    enum ExportFormat { case pdf, image }

    private var paidInstallments: [Installment] { financing.installments.filter { $0.payment != nil } }
    private var openInstallments: [Installment] { financing.installments.filter { $0.status == .open } }
    private var overdueInstallments: [Installment] { financing.installments.filter { $0.status == .overdue } }
    private var totalPaid: Double { paidInstallments.compactMap(\.payment).reduce(0) { $0 + $1.paidAmount } }
    private var totalRemaining: Double { financing.installments.filter { $0.payment == nil }.reduce(0) { $0 + $1.amount } }
    private var totalInterestPaid: Double { paidInstallments.compactMap(\.payment).enumerated().reduce(0) { acc, pair in
        let inst = financing.installments.first { $0.payment != nil && $0.number == pair.offset + 1 }
        return acc + (inst?.interestAmount ?? 0)
    }}
    private var totalPrincipalPaid: Double { paidInstallments.reduce(0) { $0 + $1.principalAmount } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "report.summary"))
                        .font(.headline)
                    statRow(String(localized: "report.paid.count"),
                            "\(paidInstallments.count)/\(financing.totalInstallments)")
                    statRow(String(localized: "report.open.count"), "\(openInstallments.count)")
                    statRow(String(localized: "report.overdue.count"), "\(overdueInstallments.count)")
                    Divider()
                    statRow(String(localized: "report.total.paid"), totalPaid.currencyFormatted)
                    statRow(String(localized: "report.total.remaining"), totalRemaining.currencyFormatted)
                    Divider()
                    statRow(String(localized: "report.principal.paid"), totalPrincipalPaid.currencyFormatted)
                    statRow(String(localized: "report.interest.paid"),
                            financing.installments.filter { $0.payment != nil }.reduce(0) { $0 + $1.interestAmount }.currencyFormatted)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Send Report button
                Button {
                    exportFormat = .pdf
                } label: {
                    Label(String(localized: "report.send"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // Installment table
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "report.table.title"))
                        .font(.headline)
                    ForEach(financing.installments.sorted { $0.number < $1.number }) { inst in
                        HStack {
                            Text("#\(inst.number)")
                                .font(.caption.monospacedDigit())
                                .frame(width: 32, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(inst.dueDate, style: .date)
                                    .font(.caption)
                                Text(inst.amount.currencyFormatted)
                                    .font(.caption.bold())
                            }
                            Spacer()
                            Image(systemName: inst.status.systemImage)
                                .foregroundStyle(statusColor(inst.status))
                        }
                        .padding(.vertical, 4)
                        if inst.number < financing.totalInstallments {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle(String(localized: "report.title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "report.export.format"),
            isPresented: Binding(get: { exportFormat != nil }, set: { if !$0 { exportFormat = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "report.export.pdf")) { exportAsPDF() }
            Button(String(localized: "report.export.image")) { exportAsImage() }
            Button(String(localized: "action.cancel"), role: .cancel) { exportFormat = nil }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    private func exportAsPDF() {
        exportFormat = nil
        let data = PDFExporter.generate(financing: financing)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(financing.carName)-report.pdf")
        try? data.write(to: url)
        shareItems = [url]
        showShareSheet = true
    }

    private func exportAsImage() {
        exportFormat = nil
        let renderer = ImageRenderer(content: ReportSnapshotView(financing: financing))
        renderer.scale = 3
        if let img = renderer.uiImage {
            shareItems = [img]
            showShareSheet = true
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }

    private func statusColor(_ status: InstallmentStatus) -> Color {
        switch status {
        case .paid:    return .green
        case .open:    return .blue
        case .overdue: return .red
        }
    }
}

// MARK: - Snapshot view for image export

private struct ReportSnapshotView: View {
    let financing: Financing

    private var paidCount: Int { financing.installments.filter { $0.payment != nil }.count }
    private var totalPaid: Double { financing.installments.compactMap(\.payment).reduce(0) { $0 + $1.paidAmount } }
    private var totalRemaining: Double { financing.installments.filter { $0.payment == nil }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(financing.carName).font(.title2.bold())
            Text(financing.bank).foregroundStyle(.secondary)
            Divider()
            HStack {
                VStack(alignment: .leading) {
                    Text(String(localized: "report.paid.count")).font(.caption).foregroundStyle(.secondary)
                    Text("\(paidCount)/\(financing.totalInstallments)").font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(localized: "report.total.paid")).font(.caption).foregroundStyle(.secondary)
                    Text(totalPaid.currencyFormatted).font(.headline).foregroundStyle(.green)
                }
            }
            HStack {
                VStack(alignment: .leading) {
                    Text(String(localized: "report.total.remaining")).font(.caption).foregroundStyle(.secondary)
                    Text(totalRemaining.currencyFormatted).font(.headline).foregroundStyle(.orange)
                }
                Spacer()
            }
            ProgressView(value: Double(paidCount), total: Double(financing.totalInstallments))
                .tint(.blue)
            Text(String(localized: "report.generated.by"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .frame(width: 360)
    }
}

// MARK: - ShareSheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

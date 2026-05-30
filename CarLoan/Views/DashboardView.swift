import SwiftUI

struct DashboardView: View {
    let financing: Financing
    @Environment(\.modelContext) private var context

    private var paidInstallments: [Installment] {
        financing.installments.filter { $0.payment != nil }
    }
    private var unpaidInstallments: [Installment] {
        financing.installments.filter { $0.payment == nil }.sorted { $0.number < $1.number }
    }
    private var nextInstallment: Installment? { unpaidInstallments.first }
    private var totalPaid: Double { paidInstallments.compactMap(\.payment).reduce(0) { $0 + $1.paidAmount } }
    private var totalRemaining: Double { unpaidInstallments.reduce(0) { $0 + $1.amount } }
    private var progress: Double {
        guard financing.totalInstallments > 0 else { return 0 }
        return Double(paidInstallments.count) / Double(financing.totalInstallments)
    }
    private var currentMonthInstallment: Installment? {
        financing.installments.first { $0.isCurrentMonth }
    }
    private var daysUntilNext: Int? {
        guard let next = nextInstallment else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: next.dueDate).day
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress card
                VStack(spacing: 10) {
                    HStack {
                        Text("\(paidInstallments.count)/\(financing.totalInstallments)")
                            .font(.title2.bold())
                        Text(String(localized: "dashboard.installments"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(progress.formatted(.percent.precision(.fractionLength(0))))
                            .font(.headline)
                    }
                    ProgressView(value: progress)
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Amounts
                HStack(spacing: 16) {
                    amountCard(
                        title: String(localized: "dashboard.paid"),
                        value: totalPaid,
                        color: .green
                    )
                    amountCard(
                        title: String(localized: "dashboard.remaining"),
                        value: totalRemaining,
                        color: .orange
                    )
                }

                // Current month installment
                if let current = currentMonthInstallment {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(String(localized: "dashboard.this.month"))
                                .font(.headline)
                            Spacer()
                            Text(String(localized: "dashboard.installment") + " #\(current.number)")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text(current.dueDate, style: .date)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                if current.payment != nil {
                                    Label(String(localized: "status.paid"), systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            Spacer()
                            Text(current.amount.currencyFormatted)
                                .font(.title3.bold())
                                .foregroundStyle(current.payment != nil ? .green : .primary)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // Next unpaid installment (if different from current month)
                if let next = nextInstallment, !next.isCurrentMonth {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "dashboard.next.title"))
                            .font(.headline)
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(localized: "dashboard.installment") + " #\(next.number)")
                                    .font(.subheadline)
                                Text(next.dueDate, style: .date)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(next.amount.currencyFormatted)
                                    .font(.title3.bold())
                                if let days = daysUntilNext {
                                    Text(days >= 0
                                         ? String(format: String(localized: "dashboard.days.left"), days)
                                         : String(localized: "dashboard.overdue"))
                                        .font(.caption)
                                        .foregroundStyle(days < 0 ? .red : .secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // Action buttons
                VStack(spacing: 12) {
                    NavigationLink {
                        InstallmentListView(financing: financing)
                    } label: {
                        Label(String(localized: "dashboard.see.installments"), systemImage: "list.number")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        ReportView(financing: financing)
                    } label: {
                        Label(String(localized: "dashboard.see.report"), systemImage: "chart.bar.doc.horizontal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        SimulationView(financing: financing)
                    } label: {
                        Label(String(localized: "dashboard.simulate"), systemImage: "function")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle(financing.carName)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func amountCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.currencyFormatted)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

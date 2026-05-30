import SwiftUI
import PhotosUI

struct DashboardView: View {
    let financing: Financing
    @Environment(\.modelContext) private var context

    @State private var showEdit = false
    @State private var quickPayInstallment: Installment?
    @State private var showQuickPay = false

    private var vm: InstallmentViewModel { InstallmentViewModel(context: context) }

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
    private var totalAllInstallments: Double { totalPaid + totalRemaining }

    private var currentMonthInstallment: Installment? {
        financing.installments.first { $0.isCurrentMonth }
    }
    private var featuredInstallment: Installment? {
        // Prefer current month if unpaid, else next unpaid
        if let current = currentMonthInstallment, current.payment == nil { return current }
        return nextInstallment
    }
    private var daysUntilFeatured: Int? {
        guard let inst = featuredInstallment else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: inst.dueDate).day
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

                // Original value + total cost
                VStack(spacing: 4) {
                    if financing.vehicleValue > 0 {
                        HStack {
                            Text(String(localized: "dashboard.original.value"))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(financing.vehicleValue.currencyFormatted)
                                .font(.subheadline.bold())
                        }
                    }
                    HStack {
                        Text(String(localized: "dashboard.total.cost"))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(totalAllInstallments.currencyFormatted)
                            .font(.subheadline.bold())
                    }
                }
                .padding(.horizontal, 4)

                // Amounts
                HStack(spacing: 16) {
                    amountCard(title: String(localized: "dashboard.paid"), value: totalPaid, color: .green)
                    amountCard(title: String(localized: "dashboard.remaining"), value: totalRemaining, color: .orange)
                }

                // ── Quick pay card ──
                quickPayCard

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "action.edit")) {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditFinancingView(financing: financing)
        }
        // Quick pay sheet
        .sheet(isPresented: $showQuickPay) {
            if let inst = quickPayInstallment {
                QuickPaySheet(installment: inst, vm: vm) {
                    showQuickPay = false
                }
            }
        }
    }

    // MARK: - Quick pay card

    @ViewBuilder
    private var quickPayCard: some View {
        if let inst = featuredInstallment {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(inst.isCurrentMonth
                                 ? String(localized: "dashboard.this.month")
                                 : String(localized: "dashboard.next.title"))
                                .font(.headline)
                            if inst.isCurrentMonth {
                                Text(String(localized: "dashboard.this.month.badge"))
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.blue.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                        }
                        Text(String(localized: "dashboard.installment") + " #\(inst.number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(inst.amount.currencyFormatted)
                            .font(.title2.bold())
                        if let days = daysUntilFeatured {
                            Text(days > 0
                                 ? String(format: String(localized: "dashboard.days.left"), days)
                                 : days == 0
                                    ? String(localized: "dashboard.due.today")
                                    : String(localized: "dashboard.overdue"))
                                .font(.caption.bold())
                                .foregroundStyle(days < 0 ? .red : days == 0 ? .orange : .secondary)
                        }
                    }
                }

                Text(inst.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Mark as paid button
                if inst.payment == nil {
                    Button {
                        quickPayInstallment = inst
                        showQuickPay = true
                    } label: {
                        Label(String(localized: "dashboard.quick.pay"), systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(inst.status == .overdue ? .red : .blue)
                } else {
                    Label(String(localized: "status.paid"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func amountCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.currencyFormatted).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick pay sheet

private struct QuickPaySheet: View {
    let installment: Installment
    let vm: InstallmentViewModel
    let onDone: () -> Void

    @State private var paidDate = Date()
    @State private var paidAmount: Double
    @State private var note = ""
    init(installment: Installment, vm: InstallmentViewModel, onDone: @escaping () -> Void) {
        self.installment = installment
        self.vm = vm
        self.onDone = onDone
        _paidAmount = State(initialValue: installment.amount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(String(localized: "action.cancel")) { onDone() }
                Spacer()
                Text(String(format: String(localized: "detail.title"), installment.number))
                    .font(.headline)
                Spacer()
                Button(String(localized: "action.save")) { save() }
                    .bold()
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Payment info
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker(String(localized: "detail.paid.date"), selection: $paidDate, displayedComponents: .date)
                        Divider()
                        CurrencyTextField(label: String(localized: "detail.paid.amount"), value: $paidAmount)
                        Divider()
                        TextField(String(localized: "detail.note.optional"), text: $note)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // Info (read-only)
                    VStack(spacing: 8) {
                        HStack {
                            Text(String(localized: "detail.due.date")).foregroundStyle(.secondary)
                            Spacer()
                            Text(installment.dueDate, style: .date)
                        }
                        Divider()
                        HStack {
                            Text(String(localized: "detail.amount")).foregroundStyle(.secondary)
                            Spacer()
                            Text(installment.amount.currencyFormatted)
                        }
                    }
                    .font(.subheadline)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
        .presentationDetents([.large, .medium])
    }

    private func save() {
        vm.markAsPaid(installment: installment, paidDate: paidDate, paidAmount: paidAmount, note: note.isEmpty ? nil : note)
        onDone()
    }
}

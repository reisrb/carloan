import SwiftUI

struct InstallmentListView: View {
    let financing: Financing
    @Environment(\.modelContext) private var context
    @State private var filter: StatusFilter = .all
    @State private var selectedInstallment: Installment?

    enum StatusFilter: String, CaseIterable {
        case all, paid, open, overdue

        var labelKey: String {
            switch self {
            case .all:     return "filter.all"
            case .paid:    return "filter.paid"
            case .open:    return "filter.open"
            case .overdue: return "filter.overdue"
            }
        }
    }

    private var filtered: [Installment] {
        let sorted = financing.installments.sorted { $0.number < $1.number }
        switch filter {
        case .all:     return sorted
        case .paid:    return sorted.filter { $0.status == .paid }
        case .open:    return sorted.filter { $0.status == .open }
        case .overdue: return sorted.filter { $0.status == .overdue }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "filter.label"), selection: $filter) {
                ForEach(StatusFilter.allCases, id: \.self) { f in
                    Text(String(localized: String.LocalizationValue(f.labelKey))).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List(filtered) { installment in
                Button {
                    selectedInstallment = installment
                } label: {
                    InstallmentRowView(installment: installment)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "installments.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedInstallment) { inst in
            InstallmentDetailView(installment: inst)
        }
    }
}

private struct InstallmentRowView: View {
    let installment: Installment

    var body: some View {
        HStack {
            Image(systemName: installment.status.systemImage)
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "installments.row.number"), installment.number))
                    .font(.subheadline.bold())
                Text(installment.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(installment.amount.currencyFormatted)
                    .font(.subheadline)
                Text(installment.remainingBalance.currencyFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch installment.status {
        case .paid:    return .green
        case .open:    return .blue
        case .overdue: return .red
        }
    }
}

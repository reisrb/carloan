import SwiftUI

struct SimulationView: View {
    let financing: Financing

    @State private var selected: Set<Int> = []
    @State private var mode: AmortizationMode = .reduceTerm

    enum AmortizationMode: String, CaseIterable {
        case reduceTerm    = "simulation.mode.term"
        case reducePayment = "simulation.mode.payment"
    }

    private var allRows: [LoanCalculator.InstallmentRow] {
        LoanCalculator.priceTable(
            financedAmount: financing.financedAmount,
            monthlyRate: financing.monthlyRate,
            totalInstallments: financing.totalInstallments,
            firstDueDate: financing.firstDueDate
        )
    }

    private var unpaid: [Installment] {
        financing.installments.filter { $0.payment == nil }.sorted { $0.number < $1.number }
    }

    private var paidNumbers: Set<Int> {
        Set(financing.installments.filter { $0.payment != nil }.map(\.number))
    }

    private var result: LoanCalculator.AmortizationResult? {
        guard !selected.isEmpty else { return nil }
        return LoanCalculator.amortize(
            allRows: allRows,
            paidNumbers: paidNumbers,
            selectedNumbers: selected,
            monthlyRate: financing.monthlyRate
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick presets
                quickPresetsCard

                // Mode picker
                Picker(String(localized: "simulation.mode.label"), selection: $mode) {
                    ForEach(AmortizationMode.allCases, id: \.self) { m in
                        Text(String(localized: String.LocalizationValue(m.rawValue))).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Installment picker list
                installmentPickerCard

                // Result
                if let res = result {
                    resultCard(res)
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "simulation.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Quick presets

    private var quickPresetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "simulation.quick.select"))
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetButton(String(localized: "simulation.preset.last"), action: selectLast)
                    presetButton(String(localized: "simulation.preset.next2"), action: { selectNext(2) })
                    presetButton(String(localized: "simulation.preset.next3"), action: { selectNext(3) })
                    presetButton(String(localized: "simulation.preset.next6"), action: { selectNext(6) })
                    presetButton(String(localized: "simulation.preset.all"), action: selectAll)
                    if !selected.isEmpty {
                        Button(String(localized: "simulation.preset.clear")) { selected.removeAll() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func presetButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
    }

    // MARK: - Installment picker

    private var installmentPickerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "simulation.select.installments"))
                .font(.headline)
                .padding()

            ForEach(unpaid) { inst in
                let isSelected = selected.contains(inst.number)
                Button {
                    if isSelected { selected.remove(inst.number) } else { selected.insert(inst.number) }
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(String(format: String(localized: "installments.row.number"), inst.number))
                                    .font(.subheadline.bold())
                                if inst.isCurrentMonth {
                                    Text(String(localized: "simulation.current.month"))
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(inst.dueDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(inst.principalAmount.currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                            Text(String(localized: "simulation.principal.label"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(isSelected ? Color.blue.opacity(0.06) : Color.clear)
                Divider().padding(.leading)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Result card

    @ViewBuilder
    private func resultCard(_ res: LoanCalculator.AmortizationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "simulation.result"))
                .font(.headline)

            resultRow(String(localized: "simulation.selected.count"), "\(res.selectedNumbers.count)")
            resultRow(String(localized: "simulation.total.to.pay"), res.principalToPayNow.currencyFormatted)
            resultRow(String(localized: "simulation.interest.skipped"), res.interestSkipped.currencyFormatted)

            Divider()

            if mode == .reduceTerm {
                resultRow(String(localized: "simulation.new.count"), "\(res.reduceTerm.newInstallmentCount)")
                if let date = res.reduceTerm.newPayoffDate {
                    resultRow(String(localized: "simulation.payoff.date"), date.formatted(date: .abbreviated, time: .omitted))
                }
                resultRow(String(localized: "simulation.interest.saved"), res.reduceTerm.totalInterestSaved.currencyFormatted)
                    .foregroundStyle(.green)
            } else {
                resultRow(String(localized: "simulation.new.monthly"), res.reduceMonthly.newMonthlyPayment.currencyFormatted)
                resultRow(String(localized: "simulation.saving.per.month"), res.reduceMonthly.savingPerMonth.currencyFormatted)
                resultRow(String(localized: "simulation.interest.saved"), res.reduceMonthly.totalInterestSaved.currencyFormatted)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }

    // MARK: - Preset actions

    private func selectLast() {
        guard let last = unpaid.last else { return }
        selected = [last.number]
    }

    private func selectNext(_ count: Int) {
        let numbers = unpaid.prefix(count).map(\.number)
        selected = Set(numbers)
    }

    private func selectAll() {
        selected = Set(unpaid.map(\.number))
    }
}

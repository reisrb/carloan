import SwiftUI

struct SimulationView: View {
    let financing: Financing
    @State private var fromInstallment = 1

    private var unpaid: [Installment] {
        financing.installments.filter { $0.payment == nil }.sorted { $0.number < $1.number }
    }

    private var allRows: [LoanCalculator.InstallmentRow] {
        LoanCalculator.priceTable(
            financedAmount: financing.financedAmount,
            monthlyRate: financing.monthlyRate,
            totalInstallments: financing.totalInstallments,
            firstDueDate: financing.firstDueDate
        )
    }

    private var result: LoanCalculator.EarlyPayoffResult? {
        guard !allRows.isEmpty else { return nil }
        return LoanCalculator.earlyPayoff(allInstallments: allRows, fromNumber: fromInstallment)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "simulation.from"))
                        .font(.headline)
                    Stepper(
                        String(format: String(localized: "simulation.installment"), fromInstallment),
                        value: $fromInstallment,
                        in: 1...financing.totalInstallments
                    )
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                if let res = result {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "simulation.result"))
                            .font(.headline)
                        resultRow(String(localized: "simulation.installments.count"),
                                  "\(res.installmentsToPay.count)")
                        resultRow(String(localized: "simulation.total.to.pay"),
                                  res.totalAmount.currencyFormatted)
                        resultRow(String(localized: "simulation.interest.saved"),
                                  res.interestSaved.currencyFormatted)
                        if let payoffDate = res.newPayoffDate {
                            resultRow(String(localized: "simulation.payoff.date"),
                                      payoffDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        Divider()

                        let normalTotal = allRows.dropFirst(fromInstallment - 1).reduce(0) { $0 + $1.amount }
                        resultRow(String(localized: "simulation.normal.total"), normalTotal.currencyFormatted)
                        let saving = normalTotal - res.totalAmount
                        resultRow(String(localized: "simulation.saving"), saving.currencyFormatted)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "simulation.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fromInstallment = unpaid.first?.number ?? 1
        }
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
}

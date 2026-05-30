import Foundation

struct LoanCalculator {
    struct InstallmentRow {
        let number: Int
        let dueDate: Date
        let amount: Double
        let principalAmount: Double
        let interestAmount: Double
        let remainingBalance: Double
    }

    /// Price (French amortization) table.
    static func priceTable(
        financedAmount: Double,
        monthlyRate: Double,
        totalInstallments: Int,
        firstDueDate: Date
    ) -> [InstallmentRow] {
        guard monthlyRate > 0, totalInstallments > 0, financedAmount > 0 else { return [] }

        let i = monthlyRate
        let n = Double(totalInstallments)
        let pmt = financedAmount * (i * pow(1 + i, n)) / (pow(1 + i, n) - 1)

        var rows: [InstallmentRow] = []
        var balance = financedAmount
        let calendar = Calendar.current

        for k in 1...totalInstallments {
            let interest = balance * i
            let principal = pmt - interest
            balance -= principal

            let dueDate = calendar.date(
                byAdding: .month,
                value: k - 1,
                to: firstDueDate
            ) ?? firstDueDate

            rows.append(InstallmentRow(
                number: k,
                dueDate: dueDate,
                amount: pmt,
                principalAmount: principal,
                interestAmount: interest,
                remainingBalance: max(0, balance)
            ))
        }
        return rows
    }

    /// Total interest paid if all installments go to term.
    static func totalInterest(financedAmount: Double, monthlyRate: Double, totalInstallments: Int) -> Double {
        let rows = priceTable(
            financedAmount: financedAmount,
            monthlyRate: monthlyRate,
            totalInstallments: totalInstallments,
            firstDueDate: Date()
        )
        return rows.reduce(0) { $0 + $1.interestAmount }
    }

    struct EarlyPayoffResult {
        let installmentsToPay: [InstallmentRow]
        let totalAmount: Double
        let interestSaved: Double
        let newPayoffDate: Date?
    }

    /// Simulate paying off N installments early (all remaining starting from `fromNumber`).
    static func earlyPayoff(
        allInstallments: [InstallmentRow],
        fromNumber: Int
    ) -> EarlyPayoffResult {
        let remaining = allInstallments.filter { $0.number >= fromNumber }
        let total = remaining.reduce(0) { $0 + $1.principalAmount }
        let interestSaved = remaining.reduce(0) { $0 + $1.interestAmount }
        return EarlyPayoffResult(
            installmentsToPay: remaining,
            totalAmount: total,
            interestSaved: interestSaved,
            newPayoffDate: remaining.last?.dueDate
        )
    }
}

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

    /// Price (French amortization) table. When monthlyRate = 0, uses equal installments (no interest).
    static func priceTable(
        financedAmount: Double,
        monthlyRate: Double,
        totalInstallments: Int,
        firstDueDate: Date
    ) -> [InstallmentRow] {
        guard totalInstallments > 0, financedAmount > 0 else { return [] }

        let i = monthlyRate
        let n = Double(totalInstallments)
        let pmt = i > 0
            ? financedAmount * (i * pow(1 + i, n)) / (pow(1 + i, n) - 1)
            : financedAmount / n

        var rows: [InstallmentRow] = []
        var balance = financedAmount
        let calendar = Calendar.current

        for k in 1...totalInstallments {
            let interest = balance * i
            let principal = pmt - interest
            balance -= principal

            let dueDate = calendar.date(byAdding: .month, value: k - 1, to: firstDueDate) ?? firstDueDate

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

    // MARK: - Amortization simulation

    struct AmortizationResult {
        /// Numbers of the selected installments
        let selectedNumbers: [Int]
        /// Principal sum to pay now (no interest charged on early payment)
        let principalToPayNow: Double
        /// Interest skipped on selected installments
        let interestSkipped: Double

        // Reduce term: fewer installments, same PMT
        struct ReduceTerm {
            let newInstallmentCount: Int
            let newPayoffDate: Date?
            let totalInterestSaved: Double
        }
        let reduceTerm: ReduceTerm

        // Reduce monthly: same installment count, lower PMT
        struct ReduceMonthly {
            let newMonthlyPayment: Double
            let savingPerMonth: Double
            let totalInterestSaved: Double
        }
        let reduceMonthly: ReduceMonthly
    }

    /// Simulate paying selected unpaid installments' principal early.
    ///
    /// - Parameters:
    ///   - allRows: Full Price table for the financing
    ///   - paidNumbers: Installment numbers already paid (excluded from simulation)
    ///   - selectedNumbers: Installment numbers the user wants to anticipate
    ///   - monthlyRate: Financing monthly rate
    static func amortize(
        allRows: [InstallmentRow],
        paidNumbers: Set<Int>,
        selectedNumbers: Set<Int>,
        monthlyRate: Double
    ) -> AmortizationResult? {
        guard !selectedNumbers.isEmpty else { return nil }

        let selected = allRows.filter { selectedNumbers.contains($0.number) }
        let principalNow = selected.reduce(0) { $0 + $1.principalAmount }
        let interestSkipped = selected.reduce(0) { $0 + $1.interestAmount }

        // All unpaid rows (excluding already paid ones)
        let unpaid = allRows.filter { !paidNumbers.contains($0.number) }.sorted { $0.number < $1.number }
        // Remaining after removing selected
        let remaining = unpaid.filter { !selectedNumbers.contains($0.number) }

        // Current balance before anticipation = last unpaid row's remaining balance after previous
        // Use the balance from the installment just before the first selected or unpaid
        let balanceBeforeSelected: Double = {
            guard let firstSelected = allRows.filter({ selectedNumbers.contains($0.number) }).min(by: { $0.number < $1.number }) else { return 0 }
            let prevNumber = firstSelected.number - 1
            if prevNumber == 0 {
                return allRows.first.map { $0.principalAmount + $0.interestAmount + $0.remainingBalance } ?? 0
            }
            return allRows.first(where: { $0.number == prevNumber })?.remainingBalance ?? 0
        }()

        let newBalance = max(0, balanceBeforeSelected - principalNow)

        // Reduce term: newBalance / same PMT → how many installments remain
        let n = remaining.count
        let reduceTerm: AmortizationResult.ReduceTerm = {
            let normalInterestOnRemaining = remaining.reduce(0) { $0 + $1.interestAmount }
            // New table from newBalance with same PMT
            var newTableCount = 0
            var bal = newBalance
            let pmt = unpaid.first?.amount ?? 0
            if pmt > 0 {
                while bal > 0.01 && newTableCount < 1200 {
                    let interest = bal * monthlyRate
                    let principal = pmt - interest
                    if principal <= 0 { break }
                    bal -= principal
                    newTableCount += 1
                }
            }
            let newPayoffDate: Date? = remaining.dropFirst(max(0, newTableCount - 1)).first?.dueDate
            let interestSavedVsNormal = interestSkipped + (normalInterestOnRemaining - recomputeInterest(balance: newBalance, rate: monthlyRate, count: newTableCount))
            return AmortizationResult.ReduceTerm(
                newInstallmentCount: newTableCount,
                newPayoffDate: newPayoffDate ?? remaining.last?.dueDate,
                totalInterestSaved: max(0, interestSavedVsNormal)
            )
        }()

        // Reduce monthly: same remaining count, lower PMT
        let reduceMonthly: AmortizationResult.ReduceMonthly = {
            guard n > 0 else { return .init(newMonthlyPayment: 0, savingPerMonth: 0, totalInterestSaved: 0) }
            let nd = Double(n)
            let i = monthlyRate
            let newPmt = newBalance * (i * pow(1 + i, nd)) / (pow(1 + i, nd) - 1)
            let oldPmt = unpaid.first?.amount ?? 0
            let saving = max(0, oldPmt - newPmt)
            let normalInterest = remaining.reduce(0) { $0 + $1.interestAmount }
            let newInterest = recomputeInterest(balance: newBalance, rate: monthlyRate, count: n)
            return AmortizationResult.ReduceMonthly(
                newMonthlyPayment: newPmt,
                savingPerMonth: saving,
                totalInterestSaved: max(0, interestSkipped + normalInterest - newInterest)
            )
        }()

        return AmortizationResult(
            selectedNumbers: selectedNumbers.sorted(),
            principalToPayNow: principalNow,
            interestSkipped: interestSkipped,
            reduceTerm: reduceTerm,
            reduceMonthly: reduceMonthly
        )
    }

    private static func recomputeInterest(balance: Double, rate: Double, count: Int) -> Double {
        guard count > 0, balance > 0, rate > 0 else { return 0 }
        let n = Double(count)
        let i = rate
        let pmt = balance * (i * pow(1 + i, n)) / (pow(1 + i, n) - 1)
        var total = 0.0
        var bal = balance
        for _ in 0..<count {
            let interest = bal * i
            total += interest
            bal -= (pmt - interest)
        }
        return total
    }

    // MARK: - Legacy (kept for backward compat)

    struct EarlyPayoffResult {
        let installmentsToPay: [InstallmentRow]
        let totalAmount: Double
        let interestSaved: Double
        let newPayoffDate: Date?
    }

    static func earlyPayoff(allInstallments: [InstallmentRow], fromNumber: Int) -> EarlyPayoffResult {
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

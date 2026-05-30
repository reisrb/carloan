import SwiftUI
import SwiftData

@MainActor
@Observable
final class FinancingViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Primary creation path: user inputs installment amount directly.
    /// - Parameters:
    ///   - installmentAmount: Fixed monthly payment (PMT). If 0, calculated from vehicleValue/monthlyRate.
    ///   - alreadyPaidCount: Pre-mark first N installments as paid (user already paid them before adding to app).
    func createFinancing(
        carName: String,
        licensePlate: String,
        bank: String,
        vehicleValue: Double,
        downPayment: Double,
        monthlyRate: Double,
        installmentAmount: Double,
        totalInstallments: Int,
        firstDueDate: Date,
        alreadyPaidCount: Int,
        carPhotoFilename: String?
    ) {
        let financing = Financing(
            carName: carName,
            licensePlate: licensePlate,
            bank: bank,
            vehicleValue: vehicleValue,
            downPayment: downPayment,
            monthlyRate: monthlyRate,
            totalInstallments: totalInstallments,
            firstDueDate: firstDueDate,
            carPhotoFilename: carPhotoFilename
        )
        context.insert(financing)

        // Derive financedAmount: prefer vehicleValue - downPayment if > 0,
        // otherwise use installmentAmount * n (for contracts without known vehicle price)
        let financed = vehicleValue > 0
            ? max(0, vehicleValue - downPayment)
            : installmentAmount * Double(totalInstallments)

        let rows: [LoanCalculator.InstallmentRow]
        if installmentAmount > 0 && monthlyRate == 0 {
            // Flat installments — user knows the PMT, no rate
            rows = flatInstallments(amount: installmentAmount, count: totalInstallments, firstDueDate: firstDueDate)
        } else {
            rows = LoanCalculator.priceTable(
                financedAmount: financed,
                monthlyRate: monthlyRate,
                totalInstallments: totalInstallments,
                firstDueDate: firstDueDate
            )
        }

        let calendar = Calendar.current
        for row in rows {
            let inst = Installment(
                number: row.number,
                dueDate: row.dueDate,
                amount: row.amount,
                principalAmount: row.principalAmount,
                interestAmount: row.interestAmount,
                remainingBalance: row.remainingBalance
            )
            inst.financing = financing
            financing.installments.append(inst)
            context.insert(inst)

            // Pre-mark already-paid installments
            if row.number <= alreadyPaidCount {
                let estimatedPaidDate = calendar.date(
                    byAdding: .month, value: row.number - 1, to: firstDueDate
                ) ?? row.dueDate
                let payment = Payment(paidDate: estimatedPaidDate, paidAmount: row.amount)
                payment.installment = inst
                inst.payment = payment
                context.insert(payment)
            }
        }

        try? context.save()
    }

    private func flatInstallments(amount: Double, count: Int, firstDueDate: Date) -> [LoanCalculator.InstallmentRow] {
        let calendar = Calendar.current
        return (1...count).map { k in
            let dueDate = calendar.date(byAdding: .month, value: k - 1, to: firstDueDate) ?? firstDueDate
            let remaining = amount * Double(count - k)
            return LoanCalculator.InstallmentRow(
                number: k,
                dueDate: dueDate,
                amount: amount,
                principalAmount: amount,
                interestAmount: 0,
                remainingBalance: remaining
            )
        }
    }

    func delete(_ financing: Financing) {
        context.delete(financing)
        try? context.save()
    }

    func paidCount(_ financing: Financing) -> Int {
        financing.installments.filter { $0.payment != nil }.count
    }

    func totalPaid(_ financing: Financing) -> Double {
        financing.installments.compactMap(\.payment).reduce(0) { $0 + $1.paidAmount }
    }

    func totalRemaining(_ financing: Financing) -> Double {
        financing.installments.filter { $0.payment == nil }.reduce(0) { $0 + $1.amount }
    }

    func nextInstallment(_ financing: Financing) -> Installment? {
        financing.installments
            .filter { $0.payment == nil }
            .sorted { $0.number < $1.number }
            .first
    }
}

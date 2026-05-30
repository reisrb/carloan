import SwiftUI
import SwiftData

@MainActor
@Observable
final class FinancingViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createFinancing(
        carName: String,
        licensePlate: String,
        bank: String,
        vehicleValue: Double,
        downPayment: Double,
        monthlyRate: Double,
        totalInstallments: Int,
        firstDueDate: Date,
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

        let rows = LoanCalculator.priceTable(
            financedAmount: financing.financedAmount,
            monthlyRate: monthlyRate,
            totalInstallments: totalInstallments,
            firstDueDate: firstDueDate
        )
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
        }

        try? context.save()
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

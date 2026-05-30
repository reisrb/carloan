import Foundation
import SwiftData

@Model
final class Financing {
    var id: UUID
    var carName: String
    var bank: String
    var vehicleValue: Double
    var downPayment: Double
    var monthlyRate: Double
    var totalInstallments: Int
    var firstDueDate: Date
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Installment.financing)
    var installments: [Installment]

    var financedAmount: Double { vehicleValue - downPayment }

    init(
        carName: String,
        bank: String,
        vehicleValue: Double,
        downPayment: Double,
        monthlyRate: Double,
        totalInstallments: Int,
        firstDueDate: Date
    ) {
        self.id = UUID()
        self.carName = carName
        self.bank = bank
        self.vehicleValue = vehicleValue
        self.downPayment = downPayment
        self.monthlyRate = monthlyRate
        self.totalInstallments = totalInstallments
        self.firstDueDate = firstDueDate
        self.createdAt = Date()
        self.installments = []
    }
}

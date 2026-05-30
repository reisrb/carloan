import Foundation
import SwiftData

@Model
final class Financing {
    var id: UUID
    var carName: String
    var licensePlate: String
    var bank: String
    var vehicleValue: Double
    var downPayment: Double
    var monthlyRate: Double
    var totalInstallments: Int
    var firstDueDate: Date
    var createdAt: Date
    var carPhotoFilename: String?
    @Relationship(deleteRule: .cascade, inverse: \Installment.financing)
    var installments: [Installment]

    /// When rate = 0, financed amount is divided equally (no interest).
    var financedAmount: Double { vehicleValue - downPayment }

    init(
        carName: String,
        licensePlate: String = "",
        bank: String = "",
        vehicleValue: Double,
        downPayment: Double = 0,
        monthlyRate: Double = 0,
        totalInstallments: Int,
        firstDueDate: Date,
        carPhotoFilename: String? = nil
    ) {
        self.id = UUID()
        self.carName = carName
        self.licensePlate = licensePlate
        self.bank = bank
        self.vehicleValue = vehicleValue
        self.downPayment = downPayment
        self.monthlyRate = monthlyRate
        self.totalInstallments = totalInstallments
        self.firstDueDate = firstDueDate
        self.createdAt = Date()
        self.carPhotoFilename = carPhotoFilename
        self.installments = []
    }
}

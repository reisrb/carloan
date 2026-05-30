import Foundation
import SwiftData

@Model
final class Payment {
    var paidDate: Date
    var paidAmount: Double
    var note: String?
    var receiptImageFilenames: [String]
    var installment: Installment?

    init(paidDate: Date, paidAmount: Double, note: String? = nil) {
        self.paidDate = paidDate
        self.paidAmount = paidAmount
        self.note = note
        self.receiptImageFilenames = []
    }
}

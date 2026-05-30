import Foundation
import SwiftData

@Model
final class Installment {
    var number: Int
    var dueDate: Date
    var amount: Double
    var principalAmount: Double
    var interestAmount: Double
    var remainingBalance: Double
    var financing: Financing?
    @Relationship(deleteRule: .cascade, inverse: \Payment.installment)
    var payment: Payment?

    var isCurrentMonth: Bool {
        Calendar.current.isDate(dueDate, equalTo: Date(), toGranularity: .month)
    }

    var status: InstallmentStatus {
        guard payment == nil else { return .paid }
        return dueDate < Date() ? .overdue : .open
    }

    init(
        number: Int,
        dueDate: Date,
        amount: Double,
        principalAmount: Double,
        interestAmount: Double,
        remainingBalance: Double
    ) {
        self.number = number
        self.dueDate = dueDate
        self.amount = amount
        self.principalAmount = principalAmount
        self.interestAmount = interestAmount
        self.remainingBalance = remainingBalance
    }
}

enum InstallmentStatus {
    case paid, open, overdue

    var labelKey: String {
        switch self {
        case .paid:    return "status.paid"
        case .open:    return "status.open"
        case .overdue: return "status.overdue"
        }
    }

    var systemImage: String {
        switch self {
        case .paid:    return "checkmark.circle.fill"
        case .open:    return "circle"
        case .overdue: return "exclamationmark.circle.fill"
        }
    }
}

import SwiftUI
import SwiftData
import PhotosUI

@MainActor
@Observable
final class InstallmentViewModel {
    private let context: ModelContext
    var receiptItems: [PhotosPickerItem] = []
    var isLoadingReceipts = false

    init(context: ModelContext) {
        self.context = context
    }

    func markAsPaid(
        installment: Installment,
        paidDate: Date,
        paidAmount: Double,
        note: String?
    ) {
        let payment = Payment(paidDate: paidDate, paidAmount: paidAmount, note: note?.isEmpty == true ? nil : note)
        payment.installment = installment
        installment.payment = payment
        context.insert(payment)
        try? context.save()

        checkAndSendPayoffNotification(for: installment)
    }

    func undoPayment(installment: Installment) {
        guard let payment = installment.payment else { return }
        for filename in payment.receiptImageFilenames {
            ImageStorageService.delete(filename: filename)
        }
        NotificationService.cancelReminders(for: installment)
        installment.payment = nil
        context.delete(payment)
        try? context.save()
    }

    func attachReceipts(to payment: Payment, items: [PhotosPickerItem]) async {
        isLoadingReceipts = true
        defer { isLoadingReceipts = false }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            let filename = ImageStorageService.newFilename()
            try? ImageStorageService.save(image, filename: filename)
            payment.receiptImageFilenames.append(filename)
        }
        try? context.save()
    }

    func deleteReceipt(filename: String, from payment: Payment) {
        ImageStorageService.delete(filename: filename)
        payment.receiptImageFilenames.removeAll { $0 == filename }
        try? context.save()
    }

    private func checkAndSendPayoffNotification(for installment: Installment) {
        guard let financing = installment.financing else { return }
        let allPaid = financing.installments.allSatisfy { $0.payment != nil }
        if allPaid {
            NotificationService.schedulePayoffCongrats(financingName: financing.carName)
        }
    }
}

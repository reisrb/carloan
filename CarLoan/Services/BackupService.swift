import Foundation
import SwiftData

enum BackupService {
    // MARK: - Codable DTOs

    struct BackupPayment: Codable {
        let paidDate: Date
        let paidAmount: Double
        let note: String?
        let receipts: [String: String]  // filename → base64
    }

    struct BackupInstallment: Codable {
        let number: Int
        let dueDate: Date
        let amount: Double
        let principalAmount: Double
        let interestAmount: Double
        let remainingBalance: Double
        let payment: BackupPayment?
    }

    struct BackupFinancing: Codable {
        let id: String
        let carName: String
        let bank: String
        let vehicleValue: Double
        let downPayment: Double
        let monthlyRate: Double
        let totalInstallments: Int
        let firstDueDate: Date
        let createdAt: Date
        let installments: [BackupInstallment]
    }

    struct BackupFile: Codable {
        let version: Int
        let exportedAt: Date
        let financings: [BackupFinancing]
    }

    // MARK: - Export

    static func export(financings: [Financing]) throws -> Data {
        let backupFinancings = financings.map { f in
            BackupFinancing(
                id: f.id.uuidString,
                carName: f.carName,
                bank: f.bank,
                vehicleValue: f.vehicleValue,
                downPayment: f.downPayment,
                monthlyRate: f.monthlyRate,
                totalInstallments: f.totalInstallments,
                firstDueDate: f.firstDueDate,
                createdAt: f.createdAt,
                installments: f.installments.sorted { $0.number < $1.number }.map { i in
                    var receipts: [String: String] = [:]
                    if let p = i.payment {
                        for filename in p.receiptImageFilenames {
                            if let b64 = ImageStorageService.loadBase64(filename: filename) {
                                receipts[filename] = b64
                            }
                        }
                    }
                    return BackupInstallment(
                        number: i.number,
                        dueDate: i.dueDate,
                        amount: i.amount,
                        principalAmount: i.principalAmount,
                        interestAmount: i.interestAmount,
                        remainingBalance: i.remainingBalance,
                        payment: i.payment.map { p in
                            BackupPayment(
                                paidDate: p.paidDate,
                                paidAmount: p.paidAmount,
                                note: p.note,
                                receipts: receipts
                            )
                        }
                    )
                }
            )
        }
        let backup = BackupFile(version: 1, exportedAt: Date(), financings: backupFinancings)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(backup)
    }

    // MARK: - Import

    @MainActor
    static func importBackup(data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFile.self, from: data)

        for bf in backup.financings {
            let financing = Financing(
                carName: bf.carName,
                bank: bf.bank,
                vehicleValue: bf.vehicleValue,
                downPayment: bf.downPayment,
                monthlyRate: bf.monthlyRate,
                totalInstallments: bf.totalInstallments,
                firstDueDate: bf.firstDueDate
            )
            context.insert(financing)

            for bi in bf.installments {
                let installment = Installment(
                    number: bi.number,
                    dueDate: bi.dueDate,
                    amount: bi.amount,
                    principalAmount: bi.principalAmount,
                    interestAmount: bi.interestAmount,
                    remainingBalance: bi.remainingBalance
                )
                installment.financing = financing
                financing.installments.append(installment)
                context.insert(installment)

                if let bp = bi.payment {
                    let payment = Payment(paidDate: bp.paidDate, paidAmount: bp.paidAmount, note: bp.note)
                    for (filename, b64) in bp.receipts {
                        try? ImageStorageService.saveFromBase64(b64, filename: filename)
                        payment.receiptImageFilenames.append(filename)
                    }
                    payment.installment = installment
                    installment.payment = payment
                    context.insert(payment)
                }
            }
        }

        try context.save()
    }
}

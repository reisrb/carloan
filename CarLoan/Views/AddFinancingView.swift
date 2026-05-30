import SwiftUI
import PhotosUI

struct AddFinancingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Car info
    @State private var carName = ""
    @State private var licensePlate = ""
    @State private var bank = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var carPhoto: UIImage?
    @State private var savedPhotoFilename: String?

    // Financing core
    @State private var vehicleValue = ""
    @State private var installmentValue = ""
    @State private var totalInstallments = ""
    @State private var alreadyPaid = 0
    @State private var firstDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    // Advanced (optional)
    @State private var showAdvanced = false
    @State private var downPayment = ""
    @State private var monthlyRatePercent = ""

    private var instAmount: Double { doubleValue(installmentValue) }
    private var total: Int { intValue(totalInstallments) }
    private var rate: Double { doubleValue(monthlyRatePercent) / 100 }

    private var isValid: Bool {
        !carName.isEmpty && instAmount > 0 && total > 0 && alreadyPaid <= total
    }

    private var totalCost: Double { instAmount * Double(total) }
    private var alreadyPaidAmount: Double { instAmount * Double(alreadyPaid) }
    private var remainingAmount: Double { instAmount * Double(total - alreadyPaid) }

    var body: some View {
        NavigationStack {
            Form {
                // Car section
                Section(String(localized: "add.section.vehicle")) {
                    // Photo picker row
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            if let photo = carPhoto {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "car.fill")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onChange(of: photoItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    carPhoto = img
                                    let filename = ImageStorageService.newFilename()
                                    try? ImageStorageService.save(img, filename: filename)
                                    savedPhotoFilename = filename
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "add.car.photo"))
                                .font(.subheadline)
                            Text(String(localized: "add.car.photo.hint"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    TextField(String(localized: "add.car.name"), text: $carName)
                    TextField(String(localized: "add.license.plate"), text: $licensePlate)
                        .textInputAutocapitalization(.characters)
                    TextField(String(localized: "add.bank"), text: $bank)
                }

                // Financing section
                Section(String(localized: "add.section.financing")) {
                    currencyField(String(localized: "add.vehicle.value.optional"), text: $vehicleValue)
                    currencyField(String(localized: "add.installment.value"), text: $installmentValue)
                    TextField(String(localized: "add.total.installments"), text: $totalInstallments)
                        .keyboardType(.numberPad)

                    // Already paid stepper
                    Stepper(
                        String(format: String(localized: "add.already.paid"), alreadyPaid),
                        value: $alreadyPaid,
                        in: 0...max(0, total)
                    )

                    DatePicker(
                        String(localized: "add.first.due.date"),
                        selection: $firstDueDate,
                        displayedComponents: .date
                    )
                }

                // Summary
                if instAmount > 0 && total > 0 {
                    Section(String(localized: "add.section.summary")) {
                        LabeledContent(String(localized: "add.total.cost"), value: totalCost.currencyFormatted)
                        if alreadyPaid > 0 {
                            LabeledContent(String(localized: "add.already.paid.amount"), value: alreadyPaidAmount.currencyFormatted)
                                .foregroundStyle(.green)
                        }
                        LabeledContent(String(localized: "add.remaining.amount"), value: remainingAmount.currencyFormatted)
                    }
                }

                // Advanced (optional rate/down payment)
                Section {
                    Button {
                        withAnimation { showAdvanced.toggle() }
                    } label: {
                        HStack {
                            Text(String(localized: "add.advanced"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    if showAdvanced {
                        currencyField(String(localized: "add.down.payment.optional"), text: $downPayment)
                        HStack {
                            TextField(String(localized: "add.monthly.rate.optional"), text: $monthlyRatePercent)
                                .keyboardType(.decimalPad)
                            if monthlyRatePercent.isEmpty {
                                Text(String(localized: "add.monthly.rate.zero.hint"))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    @ViewBuilder
    private func currencyField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func doubleValue(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func intValue(_ s: String) -> Int {
        Int(s) ?? 0
    }

    private func save() {
        let vm = FinancingViewModel(context: context)
        vm.createFinancing(
            carName: carName,
            licensePlate: licensePlate,
            bank: bank,
            vehicleValue: doubleValue(vehicleValue),
            downPayment: doubleValue(downPayment),
            monthlyRate: rate,
            installmentAmount: instAmount,
            totalInstallments: total,
            firstDueDate: firstDueDate,
            alreadyPaidCount: alreadyPaid,
            carPhotoFilename: savedPhotoFilename
        )
        dismiss()
    }
}

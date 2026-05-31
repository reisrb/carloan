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

    // Financing core (Double for CurrencyTextField)
    @State private var vehicleValue: Double = 0
    @State private var installmentValue: Double = 0
    @State private var totalInstallments = ""
    @State private var alreadyPaid = 0
    @State private var firstDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    // Advanced
    @State private var showAdvanced = false
    @State private var downPayment: Double = 0
    @State private var monthlyRatePercent = ""

    private var total: Int { Int(totalInstallments) ?? 0 }
    private var rate: Double { Double(monthlyRatePercent.replacingOccurrences(of: ",", with: ".")) ?? 0 / 100 }

    private var isValid: Bool {
        !carName.isEmpty && installmentValue > 0 && total > 0 && alreadyPaid <= total
    }

    var body: some View {
        let selectedPhoto = carPhoto

        NavigationStack {
            Form {
                Section(String(localized: "add.section.vehicle")) {
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            if let photo = selectedPhoto {
                                Image(uiImage: photo)
                                    .resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "car.fill").font(.title2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onChange(of: photoItem) { _, item in
                            Task { @MainActor in
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
                            Text(String(localized: "add.car.photo")).font(.subheadline)
                            Text(String(localized: "add.car.photo.hint")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    TextField(String(localized: "add.car.name"), text: $carName)
                    TextField(String(localized: "add.license.plate"), text: $licensePlate)
                        .textInputAutocapitalization(.characters)
                    TextField(String(localized: "add.bank"), text: $bank)
                }

                Section(String(localized: "add.section.financing")) {
                    CurrencyTextField(label: String(localized: "add.vehicle.value.optional"), value: $vehicleValue)
                    CurrencyTextField(label: String(localized: "add.installment.value"), value: $installmentValue)
                    TextField(String(localized: "add.total.installments"), text: $totalInstallments)
                        .keyboardType(.numberPad)
                    Stepper(
                        String(format: String(localized: "add.already.paid"), alreadyPaid),
                        value: $alreadyPaid, in: 0...max(0, total)
                    )
                    DatePicker(String(localized: "add.first.due.date"), selection: $firstDueDate, displayedComponents: .date)
                }

                if installmentValue > 0 && total > 0 {
                    Section(String(localized: "add.section.summary")) {
                        LabeledContent(String(localized: "add.total.cost"), value: (installmentValue * Double(total)).currencyFormatted)
                        if alreadyPaid > 0 {
                            LabeledContent(String(localized: "add.already.paid.amount"), value: (installmentValue * Double(alreadyPaid)).currencyFormatted)
                                .foregroundStyle(.green)
                        }
                        LabeledContent(String(localized: "add.remaining.amount"), value: (installmentValue * Double(total - alreadyPaid)).currencyFormatted)
                    }
                }

                Section {
                    Button { withAnimation { showAdvanced.toggle() } } label: {
                        HStack {
                            Text(String(localized: "add.advanced")).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary).font(.caption)
                        }
                    }
                    if showAdvanced {
                        CurrencyTextField(label: String(localized: "add.down.payment.optional"), value: $downPayment)
                        HStack {
                            TextField(String(localized: "add.monthly.rate.optional"), text: $monthlyRatePercent)
                                .keyboardType(.decimalPad)
                            if monthlyRatePercent.isEmpty {
                                Text(String(localized: "add.monthly.rate.zero.hint"))
                                    .font(.caption).foregroundStyle(.tertiary)
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
                    Button(String(localized: "action.save")) { save() }.disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let vm = FinancingViewModel(context: context)
        vm.createFinancing(
            carName: carName,
            licensePlate: licensePlate,
            bank: bank,
            vehicleValue: vehicleValue,
            downPayment: downPayment,
            monthlyRate: (Double(monthlyRatePercent.replacingOccurrences(of: ",", with: ".")) ?? 0) / 100,
            installmentAmount: installmentValue,
            totalInstallments: total,
            firstDueDate: firstDueDate,
            alreadyPaidCount: alreadyPaid,
            carPhotoFilename: savedPhotoFilename
        )
        dismiss()
    }
}

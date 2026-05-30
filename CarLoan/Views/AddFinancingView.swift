import SwiftUI
import PhotosUI

struct AddFinancingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var carName = ""
    @State private var licensePlate = ""
    @State private var bank = ""
    @State private var vehicleValue = ""
    @State private var downPayment = ""
    @State private var monthlyRatePercent = ""
    @State private var totalInstallments = ""
    @State private var firstDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var carPhoto: UIImage?
    @State private var savedPhotoFilename: String?

    private var isValid: Bool {
        !carName.isEmpty
        && doubleValue(vehicleValue) > 0
        && intValue(totalInstallments) > 0
        && doubleValue(downPayment) < doubleValue(vehicleValue)
    }

    private var financed: Double { doubleValue(vehicleValue) - doubleValue(downPayment) }
    private var rate: Double { doubleValue(monthlyRatePercent) / 100 }
    private var n: Int { intValue(totalInstallments) }
    private var pmt: Double {
        guard financed > 0, n > 0 else { return 0 }
        if rate > 0 {
            return financed * (rate * pow(1 + rate, Double(n))) / (pow(1 + rate, Double(n)) - 1)
        }
        return financed / Double(n)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "add.section.vehicle")) {
                    // Car photo picker
                    HStack {
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

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "add.car.photo"))
                                .font(.subheadline)
                            Text(String(localized: "add.car.photo.hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField(String(localized: "add.car.name"), text: $carName)
                    TextField(String(localized: "add.license.plate"), text: $licensePlate)
                        .textInputAutocapitalization(.characters)
                    TextField(String(localized: "add.bank"), text: $bank)
                }

                Section(String(localized: "add.section.values")) {
                    currencyField(String(localized: "add.vehicle.value"), text: $vehicleValue)
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

                Section(String(localized: "add.section.term")) {
                    TextField(String(localized: "add.total.installments"), text: $totalInstallments)
                        .keyboardType(.numberPad)
                    DatePicker(
                        String(localized: "add.first.due.date"),
                        selection: $firstDueDate,
                        displayedComponents: .date
                    )
                }

                if pmt > 0 {
                    Section(String(localized: "add.section.summary")) {
                        LabeledContent(String(localized: "add.financed.amount"), value: financed.currencyFormatted)
                        LabeledContent(String(localized: "add.monthly.payment"), value: pmt.currencyFormatted)
                        LabeledContent(String(localized: "add.total.cost"), value: (pmt * Double(n)).currencyFormatted)
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
            totalInstallments: n,
            firstDueDate: firstDueDate,
            carPhotoFilename: savedPhotoFilename
        )
        dismiss()
    }
}

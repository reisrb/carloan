import SwiftUI
import PhotosUI

struct EditFinancingView: View {
    let financing: Financing
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var carName: String
    @State private var licensePlate: String
    @State private var bank: String
    @State private var vehicleValue: Double
    @State private var installmentValue: Double
    @State private var photoItem: PhotosPickerItem?
    @State private var carPhoto: UIImage?
    @State private var savedPhotoFilename: String?

    init(financing: Financing) {
        self.financing = financing
        _carName = State(initialValue: financing.carName)
        _licensePlate = State(initialValue: financing.licensePlate)
        _bank = State(initialValue: financing.bank)
        _vehicleValue = State(initialValue: financing.vehicleValue)
        let currentPMT = financing.installments.first?.amount ?? 0
        _installmentValue = State(initialValue: currentPMT)
        _savedPhotoFilename = State(initialValue: financing.carPhotoFilename)
    }

    private var isValid: Bool { !carName.isEmpty }

    var body: some View {
        let selectedPhoto = carPhoto
        let currentSavedPhotoFilename = savedPhotoFilename

        NavigationStack {
            Form {
                Section(String(localized: "add.section.vehicle")) {
                    // Photo picker
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            if let photo = selectedPhoto {
                                Image(uiImage: photo)
                                    .resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else if let filename = currentSavedPhotoFilename,
                                      let img = ImageStorageService.load(filename: filename) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "car.fill")
                                        .font(.title2).foregroundStyle(.secondary)
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
                    CurrencyTextField(label: String(localized: "edit.installment.value.unpaid"), value: $installmentValue)
                }

                Section {
                    LabeledContent(String(localized: "edit.total.installments"), value: "\(financing.totalInstallments)")
                    LabeledContent(String(localized: "edit.paid.installments"),
                                   value: "\(financing.installments.filter { $0.payment != nil }.count)")
                    LabeledContent(String(localized: "add.first.due.date"),
                                   value: financing.firstDueDate, format: .dateTime.day().month().year())
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "edit.title"))
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

    private func save() {
        let vm = FinancingViewModel(context: context)
        vm.updateFinancing(
            financing,
            carName: carName,
            licensePlate: licensePlate,
            bank: bank,
            vehicleValue: vehicleValue,
            installmentAmount: installmentValue,
            carPhotoFilename: savedPhotoFilename
        )
        dismiss()
    }
}

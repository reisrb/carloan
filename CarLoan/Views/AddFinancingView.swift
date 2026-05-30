import SwiftUI

struct AddFinancingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var carName = ""
    @State private var bank = ""
    @State private var vehicleValue = ""
    @State private var downPayment = ""
    @State private var monthlyRatePercent = ""
    @State private var totalInstallments = ""
    @State private var firstDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    private var isValid: Bool {
        !carName.isEmpty && !bank.isEmpty
        && doubleValue(vehicleValue) > 0
        && doubleValue(downPayment) >= 0
        && doubleValue(monthlyRatePercent) > 0
        && intValue(totalInstallments) > 0
        && doubleValue(downPayment) < doubleValue(vehicleValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "add.section.vehicle")) {
                    TextField(String(localized: "add.car.name"), text: $carName)
                    TextField(String(localized: "add.bank"), text: $bank)
                }
                Section(String(localized: "add.section.values")) {
                    currencyField(String(localized: "add.vehicle.value"), text: $vehicleValue)
                    currencyField(String(localized: "add.down.payment"), text: $downPayment)
                    TextField(String(localized: "add.monthly.rate"), text: $monthlyRatePercent)
                        .keyboardType(.decimalPad)
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
                if doubleValue(vehicleValue) > 0 && doubleValue(monthlyRatePercent) > 0 && intValue(totalInstallments) > 0 {
                    Section(String(localized: "add.section.summary")) {
                        let financed = doubleValue(vehicleValue) - doubleValue(downPayment)
                        let rate = doubleValue(monthlyRatePercent) / 100
                        let n = intValue(totalInstallments)
                        let pmt = n > 0 && rate > 0
                            ? financed * (rate * pow(1 + rate, Double(n))) / (pow(1 + rate, Double(n)) - 1)
                            : 0
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
            bank: bank,
            vehicleValue: doubleValue(vehicleValue),
            downPayment: doubleValue(downPayment),
            monthlyRate: doubleValue(monthlyRatePercent) / 100,
            totalInstallments: intValue(totalInstallments),
            firstDueDate: firstDueDate
        )
        dismiss()
    }
}

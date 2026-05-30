import SwiftUI
import PhotosUI

struct InstallmentDetailView: View {
    let installment: Installment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm: InstallmentViewModel?
    @State private var showMarkAsPaid = false
    @State private var showReceiptPicker = false
    @State private var showReceiptSuggestion = false
    @State private var receiptItems: [PhotosPickerItem] = []
    @State private var fullscreenImage: IdentifiableImage?

    // Pay form
    @State private var paidDate = Date()
    @State private var paidAmountText = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Info card
                    infoCard

                    // Payment section
                    if let payment = installment.payment {
                        paymentCard(payment)
                    } else {
                        Button {
                            paidAmountText = String(format: "%.2f", installment.amount)
                            showMarkAsPaid = true
                        } label: {
                            Label(String(localized: "detail.mark.paid"), systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(
                String(format: String(localized: "detail.title"), installment.number)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showMarkAsPaid) {
                markAsPaidSheet
            }
            .sheet(item: $fullscreenImage) { wrapper in
                ReceiptFullscreenView(image: wrapper.image)
            }
        }
        .onAppear {
            vm = InstallmentViewModel(context: context)
        }
    }

    // MARK: - Subviews

    private var infoCard: some View {
        VStack(spacing: 12) {
            row(String(localized: "detail.due.date"), installment.dueDate, style: .date)
            Divider()
            row(String(localized: "detail.amount"), installment.amount.currencyFormatted)
            row(String(localized: "detail.principal"), installment.principalAmount.currencyFormatted)
            row(String(localized: "detail.interest"), installment.interestAmount.currencyFormatted)
            Divider()
            row(String(localized: "detail.balance.after"), installment.remainingBalance.currencyFormatted)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func paymentCard(_ payment: Payment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "detail.paid.title"), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            row(String(localized: "detail.paid.date"), payment.paidDate, style: .date)
            row(String(localized: "detail.paid.amount"), payment.paidAmount.currencyFormatted)
            if let note = payment.note, !note.isEmpty {
                row(String(localized: "detail.note"), note)
            }

            // Receipts
            if !payment.receiptImageFilenames.isEmpty {
                Text(String(localized: "detail.receipts"))
                    .font(.subheadline.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(payment.receiptImageFilenames, id: \.self) { filename in
                            if let img = ImageStorageService.load(filename: filename) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { fullscreenImage = IdentifiableImage(image: img) }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            vm?.deleteReceipt(filename: filename, from: payment)
                                        } label: {
                                            Label(String(localized: "action.delete"), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }

            HStack {
                PhotosPicker(
                    String(localized: "detail.add.receipt"),
                    selection: $receiptItems,
                    matching: .images
                )
                .onChange(of: receiptItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task { await vm?.attachReceipts(to: payment, items: items) }
                    receiptItems = []
                }

                Spacer()

                Button(role: .destructive) {
                    vm?.undoPayment(installment: installment)
                    dismiss()
                } label: {
                    Label(String(localized: "detail.undo.payment"), systemImage: "arrow.uturn.backward")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var markAsPaidSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(String(localized: "detail.paid.date"), selection: $paidDate, displayedComponents: .date)
                    TextField(String(localized: "detail.paid.amount"), text: $paidAmountText)
                        .keyboardType(.decimalPad)
                    TextField(String(localized: "detail.note.optional"), text: $note)
                }
            }
            .navigationTitle(String(localized: "detail.mark.paid"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { showMarkAsPaid = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let amount = Double(paidAmountText.replacingOccurrences(of: ",", with: ".")) ?? installment.amount
                        vm?.markAsPaid(installment: installment, paidDate: paidDate, paidAmount: amount, note: note)
                        showMarkAsPaid = false
                        showReceiptSuggestion = true
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func row(_ label: String, _ date: Date, style: Text.DateStyle) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(date, style: style).bold()
        }
        .font(.subheadline)
    }
}

// MARK: - Receipt fullscreen

private struct ReceiptFullscreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "action.done")) { dismiss() }
                    }
                }
        }
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}


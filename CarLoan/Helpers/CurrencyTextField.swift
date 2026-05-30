import SwiftUI

struct CurrencyTextField: View {
    let label: String
    @Binding var value: Double
    @State private var displayText: String = ""

    var body: some View {
        TextField(label, text: $displayText)
            .keyboardType(.numberPad)
            .onAppear { syncFromValue() }
            .onChange(of: value) { _, _ in syncFromValue() }
            .onChange(of: displayText) { _, newText in
                let digits = newText.filter(\.isNumber)
                let cents = Int(digits) ?? 0
                let newValue = Double(cents) / 100.0
                if abs(newValue - value) > 0.001 {
                    value = newValue
                }
                // Show empty when zero so placeholder is visible
                displayText = cents == 0 ? "" : formatted(cents)
            }
    }

    private func syncFromValue() {
        let cents = Int((value * 100).rounded())
        // Only populate if value is non-zero (preserve placeholder when empty)
        let target = cents == 0 ? "" : formatted(cents)
        if displayText != target {
            displayText = target
        }
    }

    private func formatted(_ cents: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale.current
        return fmt.string(from: NSNumber(value: Double(cents) / 100.0)) ?? ""
    }
}

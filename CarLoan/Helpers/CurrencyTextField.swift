import SwiftUI

/// Text field that auto-formats currency as the user types (cents-first).
/// Bind to a `Double` — the field keeps only digit input internally and
/// converts to the locale currency format on every keystroke.
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
                // Avoid feedback loop: only update if value actually changed
                if abs(newValue - value) > 0.001 {
                    value = newValue
                }
                displayText = formatted(cents)
            }
    }

    private func syncFromValue() {
        let cents = Int((value * 100).rounded())
        let formatted = formatted(cents)
        if displayText != formatted {
            displayText = formatted
        }
    }

    private func formatted(_ cents: Int) -> String {
        let amount = Double(cents) / 100.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale.current
        return fmt.string(from: NSNumber(value: amount)) ?? ""
    }
}

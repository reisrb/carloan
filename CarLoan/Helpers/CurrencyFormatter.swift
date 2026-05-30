import Foundation

extension Double {
    var currencyFormatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = Locale.current
        return fmt.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    var percentFormatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .percent
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 4
        return fmt.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

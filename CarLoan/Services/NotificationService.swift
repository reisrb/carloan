import UserNotifications
import Foundation

enum NotificationService {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    static func scheduleReminder(for installment: Installment, daysBefore: Int) {
        let center = UNUserNotificationCenter.current()
        guard let triggerDate = Calendar.current.date(
            byAdding: .day, value: -daysBefore, to: installment.dueDate
        ) else { return }

        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title")
        content.body = String(
            format: String(localized: "notification.body"),
            installment.number,
            daysBefore
        )
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = "installment-\(installment.persistentModelID)-\(daysBefore)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    static func schedulePayoffCongrats(financingName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.payoff.title")
        content.body = String(format: String(localized: "notification.payoff.body"), financingName)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "payoff-\(UUID())",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminders(for installment: Installment) {
        let ids = [1, 3, 7].map { "installment-\(installment.persistentModelID)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

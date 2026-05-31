import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var financings: [Financing]

    @State private var notificationDays = 3
    @State private var showImportPicker = false
    @State private var showExportConfirm = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.notifications")) {
                    Picker(String(localized: "settings.remind.days"), selection: $notificationDays) {
                        Text("1 \(String(localized: "settings.day"))").tag(1)
                        Text("3 \(String(localized: "settings.days"))").tag(3)
                        Text("7 \(String(localized: "settings.days"))").tag(7)
                    }
                    // Only show when not yet authorized
                    if notifStatus != .authorized && notifStatus != .provisional {
                        Button(String(localized: "settings.request.permission")) {
                            Task {
                                _ = await NotificationService.requestPermission()
                                await refreshNotifStatus()
                                rescheduleNotifications()
                            }
                        }
                    } else {
                        Label(String(localized: "settings.notifications.enabled"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section(String(localized: "settings.data")) {
                    Button(String(localized: "settings.export")) {
                        exportData()
                    }
                    Button(String(localized: "settings.import")) {
                        showImportPicker = true
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    importData(from: url)
                case .failure(let err):
                    errorMessage = err.localizedDescription
                    showError = true
                }
            }
            .alert(String(localized: "settings.error"), isPresented: $showError) {
                Button(String(localized: "action.ok")) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await refreshNotifStatus() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await refreshNotifStatus() }
            }
        }
    }

    @MainActor
    private func refreshNotifStatus() async {
        let authorizationStatus = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
        notifStatus = authorizationStatus
    }

    private func exportData() {
        do {
            let data = try BackupService.export(financings: financings)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("carloan-backup.json")
            try data.write(to: url)
            exportURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func importData(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            try BackupService.importBackup(data: data, context: context)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func rescheduleNotifications() {
        for financing in financings {
            for installment in financing.installments where installment.payment == nil {
                NotificationService.cancelReminders(for: installment)
                NotificationService.scheduleReminder(for: installment, daysBefore: notificationDays)
            }
        }
    }
}

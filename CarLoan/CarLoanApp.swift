import SwiftUI
import SwiftData

@main
struct CarLoanApp: App {
    let container: ModelContainer
    let containerFailed: Bool
    @State private var showNotificationRequest = false

    init() {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [config]) {
            container = c
            containerFailed = false
        } else {
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [memConfig])
            containerFailed = true
        }
    }

    var body: some Scene {
        WindowGroup {
            FinancingListView()
                .alert(String(localized: "error.db.title"), isPresented: .constant(containerFailed)) {
                    Button(String(localized: "error.db.retry")) { exit(0) }
                }
                .alert(String(localized: "notif.request.title"), isPresented: $showNotificationRequest) {
                    Button(String(localized: "notif.request.enable")) {
                        Task { await NotificationService.requestPermission() }
                    }
                    Button(String(localized: "notif.request.later"), role: .cancel) {}
                } message: {
                    Text(String(localized: "notif.request.body"))
                }
                .onAppear {
                    // Ask once — only if user hasn't seen the prompt yet
                    let key = "notif_requested_v1"
                    if !UserDefaults.standard.bool(forKey: key) {
                        UserDefaults.standard.set(true, forKey: key)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showNotificationRequest = true
                        }
                    }
                }
        }
        .modelContainer(container)
    }
}

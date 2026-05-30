import SwiftUI
import SwiftData

@main
struct CarLoanApp: App {
    let container: ModelContainer
    let containerFailed: Bool

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
        }
        .modelContainer(container)
    }
}

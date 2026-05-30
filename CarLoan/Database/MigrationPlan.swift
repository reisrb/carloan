import SwiftData

/// Add a new VersionedSchema + MigrationStage here when model properties change.
/// For new optional fields or fields with defaults: use .lightweight(...).
/// For renames or data transforms: use .custom(...) with a willMigrate/didMigrate block.
/// Never remove existing schemas from the list.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

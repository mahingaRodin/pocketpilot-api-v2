import Fluent

struct AddReceiptURLToExpenses: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("expenses")
            .field("receipt_url", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("expenses")
            .deleteField("receipt_url")
            .update()
    }
}

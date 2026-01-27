import Fluent

struct AddMonthlyIncomeToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("monthly_income", .double)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("monthly_income")
            .update()
    }
}

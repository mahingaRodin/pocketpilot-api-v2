import Vapor
import Fluent

final class Expense: Model, Content, @unchecked Sendable {
    static let schema = "expenses"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "amount")
    var amount: Double
    
    @Field(key: "description")
    var description: String
    
    @Enum(key: "category")
    var category: ExpenseCategory
    
    @Field(key: "date")
    var date: Date
    
    @OptionalField(key: "notes")
    var notes: String?
    
    @OptionalField(key: "receipt_url")
    var receiptURL: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: UUID,
        amount: Double,
        description: String,
        category: ExpenseCategory,
        date: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.amount = amount
        self.description = description
        self.category = category
        self.date = date
        self.notes = notes
    }
}
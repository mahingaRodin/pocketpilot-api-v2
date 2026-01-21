import Vapor

// MARK: - Create Expense
struct CreateExpenseRequest: Content, Validatable {
    let amount: Double
    let description: String
    let category: String
    let date: Date
    let notes: String?
    
    static func validations(_ validations: inout Validations) {
        validations.add("amount", as: Double.self, is: .range(0.01...))
        validations.add("description", as: String.self, is: !.empty && .count(...255))
        validations.add("notes", as: String?.self, is: .nil || .count(...500), required: false)
    }
}

// MARK: - Update Expense
struct UpdateExpenseRequest: Content, Validatable {
    let amount: Double?
    let description: String?
    let category: String?
    let date: Date?
    let notes: String?
    
    static func validations(_ validations: inout Validations) {
        validations.add("amount", as: Double?.self, is: .nil || .range(0.01...), required: false)
        validations.add("description", as: String?.self, is: .nil || (!.empty && .count(...255)), required: false)
        validations.add("notes", as: String?.self, is: .nil || .count(...500), required: false)
    }
}

// MARK: - Expense Response
struct ExpenseResponse: Content {
    let id: UUID
    let amount: Double
    let description: String
    let category: ExpenseCategory
    let categoryDisplay: String
    let categoryIcon: String
    let date: Date
    let notes: String?
    let receiptURL: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    init(expense: Expense) {
        self.id = expense.id!
        self.amount = expense.amount
        self.description = expense.description
        self.category = expense.category
        self.categoryDisplay = expense.category.displayName
        self.categoryIcon = expense.category.icon
        self.date = expense.date
        self.notes = expense.notes
        self.receiptURL = expense.receiptURL
        self.createdAt = expense.createdAt
        self.updatedAt = expense.updatedAt
    }
}

// MARK: - Expense List Response
struct ExpenseListResponse: Content {
    let expenses: [ExpenseResponse]
    let total: Int
    let page: Int
    let perPage: Int
    let totalAmount: Double
}

// MARK: - Query Parameters
struct ExpenseQueryParams: Content {
    let page: Int?
    let perPage: Int?
    let category: ExpenseCategory?
    let startDate: Date?
    let endDate: Date?
    let sortBy: String?
    let sortOrder: String?
}
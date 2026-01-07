import Vapor
import Fluent

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "food"
    case transportation = "transportation"
    case entertainment = "entertainment"
    case shopping = "shopping"
    case bills = "bills"
    case healthcare = "healthcare"
    case education = "education"
    case travel = "travel"
    case groceries = "groceries"
    case utilities = "utilities"
    case rent = "rent"
    case insurance = "insurance"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .food: return "Food & Dining"
        case .transportation: return "Transportation"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .bills: return "Bills & Utilities"
        case .healthcare: return "Healthcare"
        case .education: return "Education"
        case .travel: return "Travel"
        case .groceries: return "Groceries"
        case .utilities: return "Utilities"
        case .rent: return "Rent & Housing"
        case .insurance: return "Insurance"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "🍽️"
        case .transportation: return "🚗"
        case .entertainment: return "🎬"
        case .shopping: return "🛍️"
        case .bills: return "📄"
        case .healthcare: return "🏥"
        case .education: return "📚"
        case .travel: return "✈️"
        case .groceries: return "🛒"
        case .utilities: return "💡"
        case .rent: return "🏠"
        case .insurance: return "🛡️"    
        case .other: return "📦"
        }
    }
}

struct CategoryResponse: Content {
    let value: String
    let displayName: String
    let icon: String
    
    init(category: ExpenseCategory) {
        self.value = category.rawValue
        self.displayName = category.displayName
        self.icon = category.icon
    }
}
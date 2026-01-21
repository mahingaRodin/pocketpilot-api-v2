import Vapor
import Fluent

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "food"
    case transportation = "transportation"
    case shopping = "shopping"
    case bills = "bills"
    case entertainment = "entertainment"
    case healthcare = "healthcare"
    case education = "education"
    case travel = "travel"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .food: return "Food & Dining"
        case .transportation: return "Transportation"
        case .shopping: return "Shopping"
        case .bills: return "Bills & Utilities"
        case .entertainment: return "Entertainment"
        case .healthcare: return "Healthcare"
        case .education: return "Education"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "🍴"
        case .transportation: return "🚗"
        case .shopping: return "🛍️"
        case .bills: return "⚡"
        case .entertainment: return "📺"
        case .healthcare: return "🏥"
        case .education: return "📚"
        case .travel: return "✈️"
        case .other: return "•••"
        }
    }
    
    /// Parse category from either rawValue or displayName
    static func from(_ string: String) -> ExpenseCategory? {
        let normalized = string.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Try rawValue mapping
        if let category = ExpenseCategory(rawValue: normalized) {
            return category
        }
        
        // Try exact match on displayName
        for category in ExpenseCategory.allCases {
            if category.displayName.lowercased() == normalized {
                return category
            }
        }
        
        // Special mappings for loose labels
        switch normalized {
        case "food", "dining", "food and dining", "food & dining":
            return .food
        case "transport", "transportation":
            return .transportation
        case "bills", "utilities", "bills and utilities", "bills & utilities":
            return .bills
        case "rent", "housing", "rent & housing":
            return .bills // Consolidating into bills for now if not present
        case "medical", "health", "healthcare":
            return .healthcare
        default:
            return nil
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
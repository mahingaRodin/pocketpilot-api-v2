import Vapor
import Fluent

enum SafeToSpendStatus: String, Content {
    case onTrack = "on_track"
    case caution = "caution"
    case overspent = "overspent"
}

struct SafeToSpendData: Content {
    let dailyAllowance: Double
    let monthlyRemaining: Double
    let daysRemaining: Int
    let status: SafeToSpendStatus
}

struct SafeToSpendService {
    static func calculateSafeToSpend(for user: User, on req: Request) async throws -> SafeToSpendData {
        let userID = try user.requireID()
        let income = user.monthlyIncome ?? 0.0
        
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        // Get expenses for this month
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$date >= startOfMonth)
            .filter(\.$date < nextMonth)
            .all()
        
        let totalSpent = expenses.reduce(0.0) { $0 + $1.amount }
        let monthlyRemaining = max(income - totalSpent, 0)
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        let daysRemaining = max(daysInMonth - currentDay + 1, 1)
        
        let dailyAllowance = monthlyRemaining / Double(daysRemaining)
        
        // Determine status
        let status: SafeToSpendStatus
        if income == 0 {
            status = .caution
        } else {
            let percentageSpent = (totalSpent / income) * 100
            let monthProgress = (Double(currentDay) / Double(daysInMonth)) * 100
            
            if totalSpent > income {
                status = .overspent
            } else if percentageSpent > monthProgress + 10 { // 10% tolerance
                status = .caution
            } else {
                status = .onTrack
            }
        }
        
        return SafeToSpendData(
            dailyAllowance: dailyAllowance,
            monthlyRemaining: monthlyRemaining,
            daysRemaining: daysRemaining,
            status: status
        )
    }
}

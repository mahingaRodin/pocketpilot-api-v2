import Vapor

struct UserEcoImpact: Content {
    let carbonFootprintKg: Double
    let treesToOffset: Double
    let score: Int // 0-100 (100 is best/lowest impact)
}

struct EcoImpactService {
    
    /// Estimated CO2e kg per $1 spent in each category
    /// Factors based on general UK/US consumption averages
    static let impactFactors: [ExpenseCategory: Double] = [
        .food: 0.8,           // Meat vs Veg average
        .transportation: 1.2, // Fuel, public transport
        .shopping: 0.5,       // Retail goods
        .bills: 1.5,          // Utilities (Electricity/Gas)
        .entertainment: 0.2,  // Digital services, low physical impact
        .healthcare: 0.3,     // Medical supplies
        .education: 0.1,      // Services
        .travel: 2.5,         // Aviation, hotels (High impact)
        .other: 0.4           // General services
    ]
    
    static func calculateImpact(for expenses: [Expense]) -> UserEcoImpact {
        var totalCarbon = 0.0
        
        for expense in expenses {
            let factor = impactFactors[expense.category] ?? 0.4
            totalCarbon += expense.amount * factor
        }
        
        // Offset calculation: 1 mature tree absorbs ~21kg CO2 per year
        // We calculate trees needed to offset this month's spending
        let treesToOffset = totalCarbon / 21.0
        
        // Eco Score logic: 
        // 0-100 score where 100 is excellent.
        // Assuming an "average" sustainable footprint is around 300kg/month
        let maxImpact = 1000.0 // Very high impact threshold
        let score = max(0, min(100, 100 - Int((totalCarbon / maxImpact) * 100)))
        
        return UserEcoImpact(
            carbonFootprintKg: totalCarbon,
            treesToOffset: treesToOffset,
            score: score
        )
    }
}

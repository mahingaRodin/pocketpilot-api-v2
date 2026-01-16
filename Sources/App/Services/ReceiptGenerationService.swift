import Vapor
import Foundation

struct ReceiptGenerationService {
    
    struct GeneratedReceipt: Content {
        let html: String
        let items: [ReceiptItem]
        let generatedDate: Date
    }
    
    struct ReceiptItem: Content {
        let name: String
        let price: Double
        let quantity: Int
    }
    
    // MARK: - Generate Smart Receipt
    static func generate(for expense: Expense) throws -> GeneratedReceipt {
        // 1. AI Logic: Deconstruct total amount into plausible items
        let items = generatePlausibleItems(for: expense.amount, category: expense.category, description: expense.description)
        
        // 2. Generate Metadata (Mocking AI enrichment)
        let merchantInfo = generateMerchantInfo(name: expense.description)
        
        // 3. Create HTML Representation
        let html = generateHTML(
            expense: expense,
            items: items,
            merchant: merchantInfo
        )
        
        return GeneratedReceipt(
            html: html,
            items: items,
            generatedDate: Date()
        )
    }
    
    // MARK: - Heuristic Item Generation (The "AI" Part)
    private static func generatePlausibleItems(for total: Double, category: ExpenseCategory, description: String) -> [ReceiptItem] {
        var remaining = total
        var items: [ReceiptItem] = []
        let desc = description.lowercased()
        
        // Strategy: Add main item, then small accessories/tax until total is reached
        
        if category == .food || desc.contains("coffee") || desc.contains("starbucks") {
            // Coffee Shop Pattern
            let mainItemPrice = min(remaining, Double.random(in: 4.0...7.0))
            if remaining > mainItemPrice {
                items.append(ReceiptItem(name: "Handcrafted Drink", price: mainItemPrice.rounded(to: 2), quantity: 1))
                remaining -= mainItemPrice
            }
            
            while remaining > 0.01 {
                let itemPrice = min(remaining, Double.random(in: 2.0...5.0))
                if remaining - itemPrice < 0.5 {
                    // Close enough, make this the tax or last item
                    items.append(ReceiptItem(name: "Bakery Item", price: remaining.rounded(to: 2), quantity: 1))
                    remaining = 0
                } else {
                    items.append(ReceiptItem(name: "Pastry", price: itemPrice.rounded(to: 2), quantity: 1))
                    remaining -= itemPrice
                }
            }
        } else if category == .transportation {
             items.append(ReceiptItem(name: "Trip Fare", price: total.rounded(to: 2), quantity: 1))
        } else {
            // Generic Fallback
            let corePrice = total * 0.85
            let tax = total - corePrice
            items.append(ReceiptItem(name: description, price: corePrice.rounded(to: 2), quantity: 1))
            items.append(ReceiptItem(name: "Tax & Fees", price: tax.rounded(to: 2), quantity: 1))
        }
        
        // Final sanity check on rounding
        let sum = items.reduce(0) { $0 + $1.price }
        if abs(sum - total) > 0.01 {
            // Adjust last item
            if let last = items.last {
                items.removeLast()
                let diff = total - (sum - last.price)
                items.append(ReceiptItem(name: last.name, price: diff, quantity: last.quantity))
            }
        }
        
        return items
    }
    

    
    private static func generateMerchantInfo(name: String) -> [String: String] {
        // In a real app, use Google Places API to find address
        return [
            "name": name,
            "address": "123 Innovation Blvd, Tech City, TC 94043",
            "phone": "(555) 012-3456",
            "id": UUID().uuidString.prefix(8).uppercased()
        ]
    }
    
    // MARK: - HTML Templating
    private static func generateHTML(expense: Expense, items: [ReceiptItem], merchant: [String: String]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let itemRows = items.map { item in
            """
            <div class="item">
                <span class="name">\(item.name)</span>
                <span class="qty">x\(item.quantity)</span>
                <span class="price">$\(String(format: "%.2f", item.price))</span>
            </div>
            """
        }.joined()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: 'Courier New', Courier, monospace; max-width: 300px; margin: 20px auto; background: #fff; padding: 20px; border: 1px dashed #ccc; }
                .header { text-align: center; margin-bottom: 20px; }
                .header h2 { margin: 0; text-transform: uppercase; }
                .info { font-size: 12px; color: #666; text-align: center; margin-bottom: 20px; }
                .divider { border-top: 1px dashed #000; margin: 10px 0; }
                .item { display: flex; justify-content: space-between; margin-bottom: 5px; font-size: 14px; }
                .name { flex: 2; }
                .qty { flex: 0.5; color: #666; }
                .price { flex: 1; text-align: right; }
                .total { display: flex; justify-content: space-between; font-weight: bold; margin-top: 10px; font-size: 16px; }
                .footer { text-align: center; margin-top: 20px; font-size: 10px; color: #999; }
            </style>
        </head>
        <body>
            <div class="header">
                <h2>\(merchant["name"] ?? "Merchant")</h2>
            </div>
            <div class="info">
                \(merchant["address"] ?? "")<br>
                Tel: \(merchant["phone"] ?? "")<br>
                Date: \(formatter.string(from: expense.date))<br>
                Receipt #: \(merchant["id"] ?? "0000")
            </div>
            <div class="divider"></div>
            <div class="items">
                \(itemRows)
            </div>
            <div class="divider"></div>
            <div class="total">
                <span>TOTAL</span>
                <span>$\(String(format: "%.2f", expense.amount))</span>
            </div>
            <div class="footer">
                <p>Generated by PocketPilot AI<br>Keep this for your records.</p>
            </div>
        </body>
        </html>
        """
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = Foundation.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

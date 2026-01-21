import Vapor
import Fluent

struct ExportService {
    
    static func generateExport(
        request: ExportRequest,
        user: User,
        on req: Request
    ) async throws -> String {
        let userID = try user.requireID()
        
        // 1. Fetch Expenses
        var query = Expense.query(on: req.db)
            .filter(\.$user.$id == userID)
        
        if let startDate = request.startDate {
            query = query.filter(\.$date >= startDate)
        }
        
        if let endDate = request.endDate {
            query = query.filter(\.$date <= endDate)
        }
        
        if let categoryString = request.category, let category = ExpenseCategory.from(categoryString) {
            query = query.filter(\.$category == category)
        }
        
        let expenses = try await query.sort(\.$date, .descending).all()
        
        // 2. Generate Content
        let filename: String
        let content: Data
        
        switch request.format {
        case .csv:
            filename = "expenses_\(userID.uuidString.prefix(8))_\(Int(Date().timeIntervalSince1970)).csv"
            content = generateCSV(expenses: expenses)
        case .pdf:
            // Generating HTML which serves as our report format
            filename = "report_\(userID.uuidString.prefix(8))_\(Int(Date().timeIntervalSince1970)).html"
            content = generateHTMLReport(expenses: expenses, user: user)
        }
        
        // 3. Save File
        let directory = req.application.directory.publicDirectory + "exports/"
        if !FileManager.default.fileExists(atPath: directory) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        
        let path = directory + filename
        try await req.fileio.writeFile(ByteBuffer(data: content), at: path)
        
        return filename
    }
    
    private static func generateCSV(expenses: [Expense]) -> Data {
        var csvString = "Date,Description,Category,Amount,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for expense in expenses {
            let date = dateFormatter.string(from: expense.date)
            let description = "\"\(expense.description.replacingOccurrences(of: "\"", with: "\"\""))\""
            let category = expense.category.displayName
            let amount = String(format: "%.2f", expense.amount)
            let notes = "\"\(expense.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? "")\""
            
            csvString += "\(date),\(description),\(category),\(amount),\(notes)\n"
        }
        
        return csvString.data(using: String.Encoding.utf8) ?? Data()
    }
    
    private static func generateHTMLReport(expenses: [Expense], user: User) -> Data {
        let total = expenses.reduce(0) { $1.amount + $0 }
        let count = expenses.count
        
        var rowsHtml = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        for expense in expenses {
            rowsHtml += """
            <tr>
                <td>\(dateFormatter.string(from: expense.date))</td>
                <td>\(expense.description)</td>
                <td><span class="category-tag">\(expense.category.icon) \(expense.category.displayName)</span></td>
                <td class="amount">$\(String(format: "%.2f", expense.amount))</td>
            </tr>
            """
        }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #333; margin: 40px; }
                .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #eee; padding-bottom: 20px; margin-bottom: 30px; }
                .logo { font-size: 24px; font-weight: bold; color: #6366f1; }
                .summary-cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 40px; }
                .card { background: #f9fafb; padding: 20px; border-radius: 12px; border: 1px solid #f3f4f6; }
                .card-label { font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 8px; }
                .card-value { font-size: 20px; font-weight: bold; color: #111827; }
                table { width: 100%; border-collapse: collapse; }
                th { text-align: left; padding: 12px; border-bottom: 2px solid #eee; color: #6b7280; font-size: 12px; text-transform: uppercase; }
                td { padding: 16px 12px; border-bottom: 1px solid #f3f4f6; }
                .amount { font-family: "SF Mono", "Monaco", "Inconsolata", monospace; font-weight: 600; text-align: right; }
                .category-tag { background: #eef2ff; color: #4338ca; padding: 4px 10px; border-radius: 99px; font-size: 13px; }
                @media print { body { margin: 0; } .card { border: 1px solid #ddd; } }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="logo">PocketPilot Report</div>
                <div class="user-info">
                    <div style="font-weight: 600;">\(user.firstName) \(user.lastName)</div>
                    <div style="font-size: 12px; color: #6b7280;">Generated on \(dateFormatter.string(from: Date()))</div>
                </div>
            </div>
            
            <div class="summary-cards">
                <div class="card">
                    <div class="card-label">Total Spent</div>
                    <div class="card-value">$\(String(format: "%.2f", total))</div>
                </div>
                <div class="card">
                    <div class="card-label">Transactions</div>
                    <div class="card-value">\(count)</div>
                </div>
                <div class="card">
                    <div class="card-label">Average Transaction</div>
                    <div class="card-value">$\(count > 0 ? String(format: "%.2f", total / Double(count)) : "0.00")</div>
                </div>
            </div>
            
            <table>
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Description</th>
                        <th>Category</th>
                        <th style="text-align: right;">Amount</th>
                    </tr>
                </thead>
                <tbody>
                    \(rowsHtml)
                </tbody>
            </table>
            
            <div style="margin-top: 50px; text-align: center; color: #9ca3af; font-size: 12px;">
                © \(Calendar.current.component(.year, from: Date())) Pocket Pilot - Your Smart Finance Assistant
            </div>
        </body>
        </html>
        """
        
        return html.data(using: String.Encoding.utf8) ?? Data()
    }
}

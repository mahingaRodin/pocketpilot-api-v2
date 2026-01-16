import Vapor
import Foundation

struct ReceiptOCRService {
    
    // MARK: - OCR Result Model
    struct OCRResult: Content {
        let merchantName: String?
        let amount: Double?
        let date: Date?
        let category: String?
        let items: [ReceiptItem]?
        let confidence: Double
        let rawText: String
    }
    
    struct ReceiptItem: Content {
        let name: String
        let quantity: Int?
        let price: Double?
    }
    
    // MARK: - Process Receipt Image
    static func processReceipt(imageData: Data, on req: Request) async throws -> OCRResult {
        // For demo/hackathon: Use Google Vision API
        // Alternative: AWS Textract, Azure Computer Vision
        
        let googleVisionKey = Environment.get("GOOGLE_VISION_API_KEY") ?? ""
        
        guard !googleVisionKey.isEmpty else {
            throw Abort(.internalServerError, reason: "OCR Service configuration error: Missing API Key")
        }
        
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Prepare Google Vision API request
        let visionURL = "https://vision.googleapis.com/v1/images:annotate?key=\(googleVisionKey)"
        
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": [
                        "content": base64Image
                    ],
                    "features": [
                        ["type": "TEXT_DETECTION"],
                        ["type": "DOCUMENT_TEXT_DETECTION"]
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var urlRequest = URLRequest(url: URL(string: visionURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData
        
        let response = try await URLSession.shared.data(for: urlRequest)
        let visionResponse = try JSONDecoder().decode(GoogleVisionResponse.self, from: response.0)
        
        // Extract and parse text
        guard let textAnnotations = visionResponse.responses.first?.textAnnotations,
              let fullText = textAnnotations.first?.description else {
             // If Google Vision fails or returns no text
             if let error = visionResponse.error ?? visionResponse.responses.first?.error {
                 req.logger.error("Google Vision API Error: \(error.message)")
                 throw Abort(.badRequest, reason: "OCR Failed: \(error.message)")
             }
             
             // No text found in valid image
             req.logger.warning("Google Vision API found no text in image")
             return OCRResult(
                 merchantName: nil,
                 amount: nil,
                 date: nil,
                 category: nil,
                 items: nil,
                 confidence: 0.0,
                 rawText: ""
             )
        }
        
        // Parse receipt data
        return parseReceiptText(fullText)
    }
    
    // MARK: - Parse Receipt Text
    private static func parseReceiptText(_ text: String) -> OCRResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var merchantName: String?
        var amount: Double?
        var date: Date?
        var category: String = "Other"
        var items: [ReceiptItem] = []
        
        // 1. Merchant Extraction (Smart Skip)
        let headerSkipWords = ["thank", "welcome", "customer", "copy", "receipt", "transaction", "visit"]
        for line in lines {
            let lower = line.lowercased()
            if !headerSkipWords.contains(where: { lower.contains($0) }) {
                merchantName = line
                break
            }
        }
        
        // 2. Amount Extraction (Strict "TOTAL" Priority)
        var maxPriceCandidate: Double = 0.0
        
        for line in lines {
            let lower = line.lowercased()
            
            // Check for explicit Total/Amount
            if (lower.contains("total") || lower.contains("amount") || lower.contains("due")) && !lower.contains("subtotal") {
                if let price = extractPriceFromLine(line) {
                    amount = price // High confidence match
                    break
                }
            }
            
            // Track max price as fallback
            if let price = extractPriceFromLine(line) {
                if price > maxPriceCandidate {
                    maxPriceCandidate = price
                }
            }
        }
        
        // Fallback amount
        if amount == nil && maxPriceCandidate > 0 {
            amount = maxPriceCandidate
        }
        
        // 3. Date Extraction
        let datePattern = "([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
        for line in lines {
            if let regex = try? NSRegularExpression(pattern: datePattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let range = Range(match.range(at: 1), in: line) {
                    let dateString = String(line[range])
                    if let parsedDate = parseDateString(dateString) {
                        date = parsedDate
                        break
                    }
                }
            }
        }
        
        // 4. Auto-categorize
        if let merchant = merchantName?.lowercased() {
            category = categorizeByMerchant(merchant)
        }
        
        // 5. Item Extraction (Multi-Pass Regex)
        // Skip metadata lines
        let skipKeywords = ["total", "subtotal", "tax", "due", "cash", "change", "visa", "mastercard", "date:", "time:", "phone:", "tel:", "thank", "welcome", "call"]
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let lower = line.lowercased()
            
            // Skip short lines or metadata
            if line.count < 3 || skipKeywords.contains(where: { lower.contains($0) }) {
                i += 1
                continue
            }
            
            // Item Regex: Looks for "Name ... Price"
            // Captures: Name (Group 1), Price (Group 2)
            // Relaxed to catch "ITEM 1 $4.99" or "Latte 4.50"
            let itemPattern = "^(.+?)\\s+[\\$]?(\\d+\\.[0-9]{2})$"
            
            if let regex = try? NSRegularExpression(pattern: itemPattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                
                var name = ""
                var price: Double = 0.0
                var quantity = 1
                
                // Name
                if let range = Range(match.range(at: 1), in: line) {
                    name = String(line[range]).trimmingCharacters(in: .whitespaces)
                }
                
                // Price
                if let range = Range(match.range(at: 2), in: line) {
                    if let p = Double(String(line[range])) {
                        price = p
                    }
                }
                
                // Check if name has leading quantity (e.g. "2x Latte")
                let qtyPattern = "^(\\d+)[xX]?\\s+(.+)"
                if let qtyRegex = try? NSRegularExpression(pattern: qtyPattern),
                   let qtyMatch = qtyRegex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
                    
                     if let qRange = Range(qtyMatch.range(at: 1), in: name),
                        let q = Int(String(name[qRange])) {
                         quantity = q
                     }
                     if let nRange = Range(qtyMatch.range(at: 2), in: name) {
                         name = String(name[nRange])
                     }
                }
                
                // Look Ahead for explicit quantity line (e.g. "x 2 @ $ 3.00")
                if i + 1 < lines.count {
                    let nextLine = lines[i+1]
                    // Regex searches for "x (Qty) @ (Price)"
                    let modifierPattern = "[xX]\\s*(\\d+)\\s*@"
                    if let modRegex = try? NSRegularExpression(pattern: modifierPattern),
                       let modMatch = modRegex.firstMatch(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine)) {
                        
                        if let qRange = Range(modMatch.range(at: 1), in: nextLine),
                           let q = Int(String(nextLine[qRange])) {
                            quantity = q
                        }
                        i += 1 // Consume modifier line
                    }
                }
                
                // Valid Item check
                // Ensure name isn't just a number and doesn't contain forbidden words
                if Double(name) == nil && name.count > 1 {
                    items.append(ReceiptItem(name: name, quantity: quantity, price: price))
                }
            }
            i += 1
        }
        
        return OCRResult(
            merchantName: merchantName,
            amount: amount,
            date: date ?? Date(),
            category: category,
            items: items.isEmpty ? nil : items,
            confidence: calculateConfidence(amount: amount, merchant: merchantName, date: date),
            rawText: text
        )
    }
    
    // MARK: - Helper Functions
    
    private static func extractPriceFromLine(_ line: String) -> Double? {
        let pricePattern = "\\$?([0-9]+\\.[0-9]{2})"
        guard let regex = try? NSRegularExpression(pattern: pricePattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(String(line[range]))
    }
    
    private static func parseDateString(_ dateString: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "MM/dd/yy",
            "MM-dd-yy",
            "yyyy-MM-dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
    
    private static func categorizeByMerchant(_ merchant: String) -> String {
        let categoryKeywords: [String: [String]] = [
            "Food": ["restaurant", "cafe", "coffee", "pizza", "burger", "food", "kitchen", "bistro", "grill", "starbucks", "mcdonalds"],
            "Shopping": ["store", "shop", "mart", "market", "retail", "boutique", "target", "walmart"],
            "Transport": ["uber", "lyft", "taxi", "gas", "fuel", "station", "parking", "shell", "chevron"],
            "Entertainment": ["cinema", "movie", "theater", "theatre", "concert", "game", "netflix", "spotify"],
            "Healthcare": ["pharmacy", "drug", "medical", "hospital", "clinic", "doctor", "cvs", "walgreens"],
            "Utilities": ["electric", "water", "internet", "phone", "utility", "att", "verizon"],
            "Travel": ["hotel", "airline", "flight", "booking", "airbnb", "expedia"]
        ]
        
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if merchant.contains(keyword) {
                    return category
                }
            }
        }
        
        return "Other"
    }
    
    private static func calculateConfidence(amount: Double?, merchant: String?, date: Date?) -> Double {
        var confidence = 0.0
        
        if amount != nil { confidence += 0.4 }
        if merchant != nil { confidence += 0.3 }
        if date != nil { confidence += 0.3 }
        
        return confidence
    }
    
    // MARK: - Mock Data for Testing
    // Mock data removed for production efficiency

}

// MARK: - Google Vision Response Models
struct GoogleVisionResponse: Codable {
    let responses: [VisionResponse]
    let error: VisionError?
}

struct VisionResponse: Codable {
    let textAnnotations: [TextAnnotation]?
    let error: VisionError?
}

struct VisionError: Codable {
    let code: Int
    let message: String
}

struct TextAnnotation: Codable {
    let description: String
}

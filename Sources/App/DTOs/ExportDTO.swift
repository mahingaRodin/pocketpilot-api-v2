import Vapor

enum ExportFormat: String, Codable {
    case csv
    case pdf
}

struct ExportRequest: Content {
    let format: ExportFormat
    let startDate: Date?
    let endDate: Date?
    let category: String?
    
    enum CodingKeys: String, CodingKey {
        case format
        case startDate = "start_date"
        case endDate = "end_date"
        case category
    }
}

struct ExportResponse: Content {
    let success: Bool
    let filename: String
    let downloadURL: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case filename
        case downloadURL = "download_url"
        case message
    }
}

struct ReportResponse: Content {
    let filename: String
    let createdAt: Date
    let size: Int
    let downloadURL: String
    
    enum CodingKeys: String, CodingKey {
        case filename
        case createdAt = "created_at"
        case size
        case downloadURL = "download_url"
    }
}

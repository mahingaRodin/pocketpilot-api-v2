import Vapor
import Fluent
import VaporToOpenAPI

struct ReportController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let reports = routes.grouped("reports")
            .grouped(JWTAuthenticator())
        
        reports.post("export", use: triggerExport)
            .openAPI(
                summary: "Trigger export",
                description: "Starts an expense export job (CSV or HTML/PDF).",
                body: .type(ExportRequest.self),
                response: .type(ExportResponse.self),
                auth: .bearer()
            )
            
        reports.get("list", use: listReports)
            .openAPI(
                summary: "List reports",
                description: "Lists all generated reports for the user.",
                response: .type([ReportResponse].self),
                auth: .bearer()
            )
            
        reports.get("download", ":filename", use: downloadReport)
            .openAPI(
                summary: "Download report",
                description: "Downloads a specific report file.",
                auth: .bearer()
            )
    }
    
    // MARK: - Post Export
    func triggerExport(req: Request) async throws -> ExportResponse {
        let user = try req.auth.require(User.self)
        let exportRequest = try req.content.decode(ExportRequest.self)
        
        let filename = try await ExportService.generateExport(request: exportRequest, user: user, on: req)
        
        let downloadURL = "/api/v1/reports/download/\(filename)"
        
        return ExportResponse(
            success: true,
            filename: filename,
            downloadURL: downloadURL,
            message: "Report generated successfully. You can download it using the link provided."
        )
    }
    
    // MARK: - List Reports
    func listReports(req: Request) async throws -> [ReportResponse] {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        
        let directory = req.application.directory.publicDirectory + "exports/"
        
        guard FileManager.default.fileExists(atPath: directory) else {
            return []
        }
        
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )
        
        // Filter files that belong to this user (based on filename prefix)
        let userPrefix = userID.uuidString.prefix(8)
        
        var reports: [ReportResponse] = []
        
        for url in fileURLs {
            let filename = url.lastPathComponent
            if filename.contains(userPrefix) {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                let size = attributes[.size] as? Int ?? 0
                
                reports.append(ReportResponse(
                    filename: filename,
                    createdAt: creationDate,
                    size: size,
                    downloadURL: "/api/v1/reports/download/\(filename)"
                ))
            }
        }
        
        return reports.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    // MARK: - Download Report
    func downloadReport(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        
        guard let filename = req.parameters.get("filename") else {
            throw Abort(.badRequest)
        }
        
        // Security check: ensure the file belongs to the user
        let userPrefix = userID.uuidString.prefix(8)
        guard filename.contains(userPrefix) else {
            throw Abort(.forbidden, reason: "You do not have permission to access this report.")
        }
        
        let path = req.application.directory.publicDirectory + "exports/" + filename
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw Abort(.notFound)
        }
        
        return try await req.fileio.asyncStreamFile(at: path)
    }
}

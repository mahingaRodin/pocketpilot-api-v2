import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("user")
        let protected = users.grouped(JWTAuthenticator())
        
        protected.get("profile", use: getProfile)
        protected.put("profile", use: updateProfile)
        protected.post("profile-picture", ":userID", use: uploadProfilePicture)
        protected.put("profile-picture", ":userID", use: updateProfilePicture)
        protected.delete("profile-picture", ":userID", use: deleteProfilePicture)
    }
    
    func getProfile(req: Request) async throws -> UserResponse {
        let user = try req.auth.require(User.self)
        return UserResponse(user: user)
    }
    
    func updateProfile(req: Request) async throws -> UserResponse {
        let user = try req.auth.require(User.self)
        
        try UserUpdateRequest.validate(content: req)
        let updateRequest = try req.content.decode(UserUpdateRequest.self)
        
        // Update fields if provided
        if let firstName = updateRequest.firstName {
            user.firstName = firstName
        }
        
        if let lastName = updateRequest.lastName {
            user.lastName = lastName
        }
        
        try await user.save(on: req.db)
        
        return UserResponse(user: user)
    }
    
    // MARK: - Profile Picture Upload
    func uploadProfilePicture(req: Request) async throws -> UserResponse {
        guard let userIDString = req.parameters.get("userID"),
              let userID = UUID(uuidString: userIDString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        struct UploadRequest: Content {
            let file: File
        }
        
        let upload = try req.content.decode(UploadRequest.self)
        
        // Validate file is an image
        guard let ext = upload.file.extension,
              ["jpg", "jpeg", "png", "gif", "webp"].contains(ext.lowercased()) else {
            throw Abort(.badRequest, reason: "Invalid file type. Only images are allowed (jpg, png, gif, webp)")
        }
        
        // Delete old profile picture if exists
        if let oldPictureURL = user.profilePictureURL {
            try await deleteProfilePictureFile(oldPictureURL, on: req)
        }
        
        // Save new profile picture
        let imageData = Data(buffer: upload.file.data)
        let pictureURL = try await saveProfilePicture(imageData, extension: ext, on: req)
        
        // Update user
        user.profilePictureURL = pictureURL
        try await user.save(on: req.db)
        
        return UserResponse(user: user)
    }
    
    // MARK: - Update Profile Picture
    func updateProfilePicture(req: Request) async throws -> UserResponse {
        // Same logic as upload
        return try await uploadProfilePicture(req: req)
    }
    
    // MARK: - Delete Profile Picture
    func deleteProfilePicture(req: Request) async throws -> UserResponse {
        guard let userIDString = req.parameters.get("userID"),
              let userID = UUID(uuidString: userIDString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        guard let pictureURL = user.profilePictureURL else {
            throw Abort(.notFound, reason: "No profile picture to delete")
        }
        
        // Delete file from disk
        try await deleteProfilePictureFile(pictureURL, on: req)
        
        // Update user
        user.profilePictureURL = nil
        try await user.save(on: req.db)
        
        return UserResponse(user: user)
    }
    
    // MARK: - Helper: Save Profile Picture
    private func saveProfilePicture(_ imageData: Data, extension ext: String, on req: Request) async throws -> String {
        let fileName = "\(UUID().uuidString).\(ext)"
        let directory = req.application.directory.publicDirectory + "profile-pictures/"
        
        // Create directory if doesn't exist
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        
        let filePath = directory + fileName
        try imageData.write(to: URL(fileURLWithPath: filePath))
        
        return "/profile-pictures/\(fileName)"
    }
    
    // MARK: - Helper: Delete Profile Picture File
    private func deleteProfilePictureFile(_ pictureURL: String, on req: Request) async throws {
        let directory = req.application.directory.publicDirectory
        let relativePath = String(pictureURL.dropFirst()) // Remove leading /
        let fullPath = directory + relativePath
        
        // Try to delete file (ignore errors if file doesn't exist)
        try? FileManager.default.removeItem(atPath: fullPath)
    }
}
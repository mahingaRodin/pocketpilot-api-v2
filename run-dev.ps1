# PowerShell script for Windows development
# Set environment variables for SQLite development
$env:USE_SQLITE = "true"
$env:JWT_SECRET = "development-secret-key-not-for-production"
$env:BASE_URL = "http://localhost:8080"

Write-Host "Starting PocketPilot API in Windows development mode..." -ForegroundColor Green
Write-Host "Environment variables set:" -ForegroundColor Yellow
Write-Host "  USE_SQLITE = $env:USE_SQLITE" -ForegroundColor Gray
Write-Host "  JWT_SECRET = [HIDDEN]" -ForegroundColor Gray
Write-Host "  BASE_URL = $env:BASE_URL" -ForegroundColor Gray
Write-Host ""

# Force clean everything to avoid SSL compilation issues
Write-Host "Cleaning all build artifacts..." -ForegroundColor Blue
if (Test-Path ".build") {
    Remove-Item -Recurse -Force ".build"
    Write-Host "Removed .build directory" -ForegroundColor Gray
}

if (Test-Path "Package.resolved") {
    Remove-Item -Force "Package.resolved"
    Write-Host "Removed Package.resolved" -ForegroundColor Gray
}

if (Test-Path "db.sqlite") {
    Remove-Item -Force "db.sqlite"
    Write-Host "Removed old database" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Resolving dependencies (this may take a while on first run)..." -ForegroundColor Blue
swift package clean
swift package resolve

Write-Host "Building project..." -ForegroundColor Blue
swift build

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful! Starting server..." -ForegroundColor Green
    Write-Host "Server will be available at: http://localhost:8080" -ForegroundColor Cyan
    Write-Host "Health check: http://localhost:8080/health" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
    Write-Host ""
    
    # Run migrations first
    Write-Host "Running database migrations..." -ForegroundColor Blue
    swift run App migrate --yes
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Migrations completed successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Start the server
        swift run App serve --hostname 0.0.0.0 --port 8080
    } else {
        Write-Host "Migration failed! Check the errors above." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Build failed! Check the errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Common solutions:" -ForegroundColor Yellow
    Write-Host "1. Make sure Swift is properly installed" -ForegroundColor Gray
    Write-Host "2. Try running: swift package clean" -ForegroundColor Gray
    Write-Host "3. Check that all dependencies are compatible" -ForegroundColor Gray
    exit 1
}
@echo off
REM Batch script for Windows development
echo Starting PocketPilot API in Windows development mode...

REM Set environment variables
set USE_SQLITE=true
set JWT_SECRET=development-secret-key-not-for-production
set BASE_URL=http://localhost:8080

echo Environment configured for SQLite development

REM Clean build artifacts
echo Cleaning build artifacts...
if exist .build rmdir /s /q .build
if exist Package.resolved del Package.resolved
if exist db.sqlite del db.sqlite

REM Build project
echo Resolving dependencies...
swift package clean
swift package resolve

echo Building project...
swift build

if %errorlevel% neq 0 (
    echo Build failed! Check the errors above.
    pause
    exit /b 1
)

echo Build successful!
echo.
echo Server will be available at: http://localhost:8080
echo Health check: http://localhost:8080/health
echo.
echo Press Ctrl+C to stop the server
echo.

REM Run migrations
echo Running database migrations...
swift run App migrate --yes

if %errorlevel% neq 0 (
    echo Migration failed!
    pause
    exit /b 1
)

echo Migrations completed successfully!
echo.

REM Start server
swift run App serve --hostname 0.0.0.0 --port 8080

pause
# PowerShell script to test the API endpoints
$baseUrl = "http://localhost:8080"

Write-Host "Testing PocketPilot API..." -ForegroundColor Green
Write-Host "Base URL: $baseUrl" -ForegroundColor Gray
Write-Host ""

# Test health endpoint
Write-Host "1. Testing health endpoint..." -ForegroundColor Blue
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET
    Write-Host "✅ Health check passed" -ForegroundColor Green
    Write-Host "   Status: $($health.status)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test user registration
Write-Host ""
Write-Host "2. Testing user registration..." -ForegroundColor Blue
$registerData = @{
    email = "test@example.com"
    password = "TestPassword123!"
    confirmPassword = "TestPassword123!"
    firstName = "John"
    lastName = "Doe"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/register" -Method POST -Body $registerData -ContentType "application/json"
    Write-Host "✅ User registration successful" -ForegroundColor Green
    Write-Host "   User ID: $($registerResponse.user.id)" -ForegroundColor Gray
    Write-Host "   Email: $($registerResponse.user.email)" -ForegroundColor Gray
    $accessToken = $registerResponse.accessToken
} catch {
    Write-Host "❌ User registration failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $errorDetails = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorDetails)
        $errorBody = $reader.ReadToEnd()
        Write-Host "   Error details: $errorBody" -ForegroundColor Red
    }
}

# Test login (if registration failed, try login with existing user)
if (-not $accessToken) {
    Write-Host ""
    Write-Host "3. Testing user login..." -ForegroundColor Blue
    $loginData = @{
        email = "test@example.com"
        password = "TestPassword123!"
    } | ConvertTo-Json

    try {
        $loginResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/login" -Method POST -Body $loginData -ContentType "application/json"
        Write-Host "✅ User login successful" -ForegroundColor Green
        $accessToken = $loginResponse.accessToken
    } catch {
        Write-Host "❌ User login failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test protected endpoint (get categories)
if ($accessToken) {
    Write-Host ""
    Write-Host "4. Testing protected endpoint (categories)..." -ForegroundColor Blue
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        $categories = Invoke-RestMethod -Uri "$baseUrl/api/v1/expenses/categories" -Method GET -Headers $headers
        Write-Host "✅ Categories endpoint successful" -ForegroundColor Green
        Write-Host "   Found $($categories.Count) categories" -ForegroundColor Gray
        $categories | ForEach-Object { Write-Host "   - $($_.displayName) $($_.icon)" -ForegroundColor Gray }
    } catch {
        Write-Host "❌ Categories endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Test creating an expense
    Write-Host ""
    Write-Host "5. Testing expense creation..." -ForegroundColor Blue
    $expenseData = @{
        amount = 25.50
        description = "Test lunch expense"
        category = "food"
        date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        notes = "API test expense"
    } | ConvertTo-Json

    try {
        $expense = Invoke-RestMethod -Uri "$baseUrl/api/v1/expenses" -Method POST -Body $expenseData -ContentType "application/json" -Headers $headers
        Write-Host "✅ Expense creation successful" -ForegroundColor Green
        Write-Host "   Expense ID: $($expense.id)" -ForegroundColor Gray
        Write-Host "   Amount: $($expense.amount)" -ForegroundColor Gray
        Write-Host "   Description: $($expense.description)" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Expense creation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "API testing completed!" -ForegroundColor Green
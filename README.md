# PocketPilot API

A Swift-based expense tracker backend built with Vapor framework.

## Features

- User authentication with JWT tokens
- Expense management (CRUD operations)
- Categorized expenses with predefined categories
- Pagination and filtering for expense lists
- Input validation and error handling
- Cross-platform database support (PostgreSQL/SQLite)

## Project Structure

```
pocketpilot-api/
├── Package.swift                 # Dependencies
├── Sources/
│   └── App/
│       ├── configure.swift       # App configuration
│       ├── routes.swift          # Route registration
│       ├── entrypoint.swift      # Entry point
│       ├── Controllers/          # API controllers
│       ├── Models/              # Database models
│       ├── DTOs/                # Data transfer objects
│       ├── Middleware/          # Custom middleware
│       ├── Migrations/          # Database migrations
│       └── Services/            # Business logic services
└── Tests/
    └── AppTests/                # Unit tests
```

## Setup

### Windows Development (Recommended)

1. **Quick Start with PowerShell:**

   ```powershell
   .\run-dev.ps1
   ```

   This script will automatically:

   - Set up SQLite for development
   - Clean and build the project
   - Run migrations
   - Start the server

2. **Manual Setup:**

   ```powershell
   # Set environment variables
   $env:USE_SQLITE = "true"
   $env:JWT_SECRET = "development-secret-key"

   # Install dependencies
   swift package resolve

   # Build project
   swift build

   # Run migrations
   swift run App migrate --yes

   # Start server
   swift run App serve
   ```

### macOS/Linux Development

1. **Install PostgreSQL:**

   ```bash
   # macOS
   brew install postgresql
   brew services start postgresql

   # Ubuntu/Debian
   sudo apt-get install postgresql postgresql-contrib
   sudo systemctl start postgresql
   ```

2. **Setup Database:**

   ```bash
   createdb pocketpilot
   ```

3. **Configure Environment:**

   ```bash
   export DATABASE_HOST=localhost
   export DATABASE_PORT=5432
   export DATABASE_USERNAME=postgres
   export DATABASE_PASSWORD=your_password
   export DATABASE_NAME=pocketpilot
   export JWT_SECRET=your_jwt_secret
   ```

4. **Run Application:**
   ```bash
   swift package resolve
   swift build
   swift run App migrate --yes
   swift run App serve
   ```

### Production Setup

1. **Environment Variables:**

   ```bash
   export DATABASE_URL=postgresql://user:pass@host:port/dbname
   export JWT_SECRET=your-production-jwt-secret
   export BASE_URL=https://your-domain.com
   ```

2. **Deploy:**
   ```bash
   swift build -c release
   swift run App migrate --yes
   swift run App serve --env production
   ```

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - Logout current session
- `POST /api/v1/auth/logout/all` - Logout all devices

### Password Management

- `POST /api/v1/auth/password/reset` - Request password reset
- `POST /api/v1/auth/password/reset/confirm` - Confirm password reset
- `POST /api/v1/auth/password/change` - Change password

### Email Verification

- `POST /api/v1/auth/email/verify` - Verify email with token
- `POST /api/v1/auth/email/resend` - Resend verification email

### User Management

- `GET /api/v1/user/profile` - Get user profile
- `PUT /api/v1/user/profile` - Update user profile

### Session Management

- `GET /api/v1/auth/sessions` - List active sessions
- `DELETE /api/v1/auth/sessions/:id` - Revoke specific session

### Expenses

- `GET /api/v1/expenses` - List expenses (with pagination and filtering)
- `POST /api/v1/expenses` - Create new expense
- `GET /api/v1/expenses/:id` - Get specific expense
- `PUT /api/v1/expenses/:id` - Update expense
- `DELETE /api/v1/expenses/:id` - Delete expense
- `GET /api/v1/expenses/categories` - Get available categories

### Health Check

- `GET /health` - Health check endpoint

## Testing

Run tests with:

```bash
swift test
```

## Troubleshooting

### Windows Issues

1. **Build Errors with async-http-client:**

   - The project is configured to use SQLite on Windows to avoid C library compatibility issues
   - Use the `run-dev.ps1` script for easiest setup

2. **Missing Dependencies:**

   ```powershell
   swift package clean
   swift package resolve
   ```

3. **Database Issues:**
   - SQLite database file (`db.sqlite`) will be created automatically
   - Delete `db.sqlite` to reset the database

### General Issues

1. **JWT Errors:**

   - Make sure `JWT_SECRET` environment variable is set
   - Use a strong secret in production

2. **Database Connection:**

   - Check database credentials and connectivity
   - Ensure database exists before running migrations

3. **Port Already in Use:**
   ```bash
   swift run App serve --port 8081
   ```

## Windows-Specific Notes

### SSL/TLS Compilation Issues

The errors you're seeing are due to Windows socket header conflicts with BoringSSL (part of swift-nio-ssl). This is a known issue with Vapor on Windows.

**Solution**: The project has been updated to use a Windows-compatible configuration:

- ✅ **SQLite-only**: No PostgreSQL dependency on Windows
- ✅ **Older Vapor version**: Better Windows compatibility
- ✅ **Simplified dependencies**: Removes SSL-dependent packages
- ✅ **Automated scripts**: `run-dev.ps1` and `run-dev.bat` handle everything

### Quick Start for Windows

1. **PowerShell (Recommended)**:

   ```powershell
   .\run-dev.ps1
   ```

2. **Command Prompt**:

   ```cmd
   run-dev.bat
   ```

3. **Test the API**:
   ```powershell
   .\test-api.ps1
   ```

### Manual Windows Setup

If scripts don't work:

```powershell
# Clean everything
Remove-Item -Recurse -Force .build -ErrorAction SilentlyContinue
Remove-Item -Force Package.resolved -ErrorAction SilentlyContinue
Remove-Item -Force db.sqlite -ErrorAction SilentlyContinue

# Set environment
$env:USE_SQLITE = "true"
$env:JWT_SECRET = "dev-secret"

# Build and run
swift package clean
swift package resolve
swift build
swift run App migrate --yes
swift run App serve
```

The Windows version provides full API functionality using SQLite instead of PostgreSQL, avoiding all SSL/networking compilation issues.

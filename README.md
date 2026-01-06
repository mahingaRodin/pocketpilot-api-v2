# PocketPilot API

A Swift-based expense tracker backend built with Vapor framework.

## Features

- User authentication with JWT tokens
- Expense management (CRUD operations)
- Categorized expenses with predefined categories
- Pagination and filtering for expense lists
- Input validation and error handling
- PostgreSQL database integration

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

1. Install dependencies:

   ```bash
   swift package resolve
   ```

2. Set up PostgreSQL database and configure environment variables:

   ```bash
   export DATABASE_HOST=localhost
   export DATABASE_PORT=5432
   export DATABASE_USERNAME=postgres
   export DATABASE_PASSWORD=your_password
   export DATABASE_NAME=pocketpilot
   export JWT_SECRET=your_jwt_secret
   ```

3. Run migrations:

   ```bash
   swift run App migrate
   ```

4. Start the server:
   ```bash
   swift run App serve
   ```

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user

### User Management

- `GET /api/v1/user/profile` - Get user profile
- `PUT /api/v1/user/profile` - Update user profile

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

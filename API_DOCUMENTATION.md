# PocketPilot API Documentation v2

Welcome to the PocketPilot API documentation. This document provides an overview of the available endpoints, authentication mechanisms, and examples for testing.

## Base URL
The API is accessible at: `http://localhost:8080/api/v1`

---

## Authentication
Most endpoints are protected and require a JWT Bearer Token.

**Header Format:**
`Authorization: Bearer <your_access_token>`

---

## 1. Auth Endpoints
### Register
Create a new user account.
- **Endpoint:** `POST /auth/register`
- **Request Body:**
```json
{
  "email": "user@example.com",
  "password": "StrongPassword123!",
  "confirmPassword": "StrongPassword123!",
  "firstName": "John",
  "lastName": "Doe"
}
```
- **Example:**
```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email": "user@example.com", "password": "StrongPassword123!", "confirmPassword": "StrongPassword123!", "firstName": "John", "lastName": "Doe"}'
```

---

### Login
Authenticate and receive tokens.
- **Endpoint:** `POST /auth/login`
- **Request Body:**
```json
{
  "email": "user@example.com",
  "password": "StrongPassword123!"
}
```
- **Example:**
```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email": "user@example.com", "password": "StrongPassword123!"}'
```

---

### Refresh Token
Get a new access token using a refresh token.
- **Endpoint:** `POST /auth/refresh`
- **Request Body:**
```json
{
  "refreshToken": "<your_refresh_token>"
}
```

---

### Get Me (Protected)
Get current user information.
- **Endpoint:** `GET /auth/me`
- **Example:**
```bash
curl -X GET http://localhost:8080/api/v1/auth/me \
     -H "Authorization: Bearer <your_access_token>"
```

---

## 2. Dashboard Endpoints
### Get Dashboard (Protected)
Retrieve summary data for the dashboard.
- **Endpoint:** `GET /dashboard`
- **Example:**
```bash
curl -X GET http://localhost:8080/api/v1/dashboard \
     -H "Authorization: Bearer <your_access_token>"
```

---

## 3. Expense Endpoints
### List Expenses (Protected)
List all expenses with filtering and pagination.
- **Endpoint:** `GET /expenses`
- **Query Parameters:**
  - `page`: Page number (default: 1)
  - `perPage`: Items per page (default: 20, max: 100)
  - `category`: Filter by category (e.g., `food`, `bills`)
  - `startDate`: ISO8601 Date
  - `endDate`: ISO8601 Date
  - `sortBy`: Field to sort by (`date`, `amount`, `description`)
  - `sortOrder`: `asc` or `desc`
- **Example:**
```bash
curl -X GET "http://localhost:8080/api/v1/expenses?page=1&perPage=10&sortBy=date&sortOrder=desc" \
     -H "Authorization: Bearer <your_access_token>"
```

---

### Create Expense (Protected)
Add a new expense.
- **Endpoint:** `POST /expenses`
- **Request Body:**
```json
{
  "amount": 42.50,
  "description": "Lunch at Cafe",
  "category": "food",
  "date": "2026-01-15T12:00:00Z",
  "notes": "Optional notes here"
}
```
- **Example:**
```bash
curl -X POST http://localhost:8080/api/v1/expenses \
     -H "Authorization: Bearer <your_access_token>" \
     -H "Content-Type: application/json" \
     -d '{"amount": 42.50, "description": "Lunch at Cafe", "category": "food", "date": "2026-01-15T12:00:00Z"}'
```

---

### Get Expense Details (Protected)
- **Endpoint:** `GET /expenses/:expenseID`

---

### Update Expense (Protected)
- **Endpoint:** `PUT /expenses/:expenseID`

---

### Delete Expense (Protected)
- **Endpoint:** `DELETE /expenses/:expenseID`

---

### List Categories (Protected)
Get available expense categories.
- **Endpoint:** `GET /expenses/categories`

---

## 4. User Profile Endpoints
### Get Profile (Protected)
- **Endpoint:** `GET /user/profile`

---

### Update Profile (Protected)
- **Endpoint:** `PUT /user/profile`
- **Request Body:**
```json
{
  "firstName": "UpdatedName",
  "lastName": "UpdatedLastName"
}
```

---

## 5. Health Check
- **Endpoint:** `GET /health` (Public)

# Frontend API Documentation

This document outlines the REST API endpoints available for the frontend application to interact with the backend services.

> [!NOTE]
> All API endpoints are prefixed with the base URL: `https://api.dutyhours.in/api/v1`

## Common Response Structure

All endpoints return a standardized JSON format. This is crucial for building your mobile app data models.

**Success Response Example:**
```json
{
  "success": true,
  "message": "Optional success message",
  "data": { ... } // Varies per endpoint
}
```

**Error Response Example:**
```json
{
  "success": false,
  "message": "Error description here"
}
```

## Authentication Overview

Most endpoints require authentication via a Bearer token.
**Header Format:** `Authorization: Bearer <your_access_token>`

Supported Roles: `USER`, `ADMIN`, `SUPERADMIN`

---

## 1. Auth Endpoints (`/auth`)

#### `POST /auth/register`
Register a new user. The account requires approval from a `SUPERADMIN` before it can be used to log in.
- **Access:** Public
- **Body Parameters:**
  - `employeeId` (string, required)
  - `name` (string, min 2 chars, required)
  - `email` (string, valid email, required)
  - `phone` (string, optional)
  - `password` (string, min 6 chars, required)
  - `division` (string, optional)
  - `designation` (string, optional)
  - `role` (string, `'USER' | 'ADMIN' | 'SUPERADMIN'`, optional)

#### `POST /auth/login`
Authenticate a user and receive an access and refresh token.
- **Access:** Public
- **Body Parameters:**
  - `email` (string, required)
  - `password` (string, required)

#### `POST /auth/refresh`
Refresh an expired access token using a refresh token.
- **Access:** Public
- **Body Parameters:**
  - `refreshToken` (string, required)

#### `GET /auth/me`
Retrieve details of the currently authenticated user.
- **Access:** Private

#### `POST /auth/logout`
Log out the currently authenticated user and invalidate their session.
- **Access:** Private

#### `POST /auth/forgot-password`
Request a password reset OTP.
- **Access:** Public
- **Body Parameters:**
  - `email` (string, required)

#### `POST /auth/reset-password`
Reset the password using the OTP.
- **Access:** Public
- **Body Parameters:**
  - `email` (string, required)
  - `otp` (string, 6 digits, required)
  - `newPassword` (string, min 6 chars, required)

---

## 2. Dashboard Endpoints (`/dashboard`)
> [!IMPORTANT]
> All endpoints in this section require authentication.

#### `GET /dashboard/stats`
Get comprehensive statistics for the dashboard.
- **Access:** Private

#### `GET /dashboard/recent-activities`
Get recent duty logs and activities.
- **Access:** Private
- **Query Parameters:**
  - `limit` (number, 1-100, optional)
  - `offset` (number, min 0, optional)
  - `type` (string, optional) - Valid options include: `SIGN_ON`, `SIGN_OFF`, `BREAK_START`, `BREAK_END`, `RELIEF`, `ALERT_7HR`, `ALERT_8HR`, `ALERT_9HR`, `ALERT_10HR`, `ALERT_11HR`, `ALERT_14HR`, `RELIEF_PLANNED`, `RELIEF_NOT_REQUIRED`, `CREW_RELIEVED`, `CREW_NOT_BOOKED`, `KEEP_ON_DUTY`, `CREW_ALREADY_RELIEVED`, `RELEASE`

#### `GET /dashboard/trends`
Get shift trends for chart visualization.
- **Access:** Private
- **Query Parameters:**
  - `days` (number, 1-90, optional)

#### `GET /dashboard/alerts-summary`
Get a summary of active alerts.
- **Access:** Private

---

## 3. Shift Management (`/shifts`)
> [!IMPORTANT]
> All endpoints in this section require authentication.

#### `GET /shifts/active/summary`
Get a summary of all currently active shifts.
- **Access:** Private (All roles)

#### `GET /shifts`
List shifts.
- **Access:** Private (All roles)
- **Query Parameters:** Can include filtering options like status, date ranges.

#### `POST /shifts`
Create a new shift.
- **Access:** Private (`ADMIN`, `SUPERADMIN`)
- **Body Payload (JSON):**
```json
{
  "trainNumber": "12345", // string, required
  "trainName": "Rajdhani Express", // string, optional
  "locomotiveNo": "WAP-7-30456", // string, required
  "locoPilot": {
    "employeeId": "EMP123", // string, required
    "name": "John Doe" // string, required
  },
  "trainManager": {
    "employeeId": "EMP456", // string, required
    "name": "Jane Smith" // string, required
  },
  "signOnDateTime": "2023-10-15T08:00:00Z", // ISO8601, required
  "trainArrivalDateTime": "2023-10-15T08:30:00Z", // ISO8601, required
  "timeOfTO": "2023-10-15T09:00:00Z", // ISO8601, optional
  "departureDateTime": "2023-10-15T09:15:00Z", // ISO8601, optional
  "signOnStation": "NDLS", // string, required
  "signOffStation": "BCT", // string, optional
  "section": "NDLS-BCT", // string, required
  "dutyType": "SP", // string: 'SP', 'WR', 'LR', optional
  "signOffDateTime": "2023-10-15T18:00:00Z" // ISO8601, optional
}
```

#### `GET /shifts/:id`
Get a single shift's details by its ID.
- **Access:** Private (All roles)

#### `PATCH /shifts/:id`
Update a shift. All fields are optional.
- **Access:** Private (`ADMIN`, `SUPERADMIN`)
- **Body Payload (JSON):**
```json
{
  "timeOfTO": "2023-10-15T09:00:00Z", // ISO8601
  "departureDateTime": "2023-10-15T09:15:00Z", // ISO8601
  "signOffDateTime": "2023-10-15T18:00:00Z", // ISO8601
  "signOffStation": "BCT",
  "section": "NDLS-BCT",
  "dutyType": "SP", // 'SP', 'WR', 'LR'
  "status": "IN_PROGRESS", // 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'RELIEF_PLANNED', 'CANCELLED'
  "reliefPlanned": true, // boolean
  "reliefReason": "Exceeded duty hours" // string
}
```

#### `DELETE /shifts/:id`
Delete a shift.
- **Access:** Private (`SUPERADMIN`)

#### `POST /shifts/:id/alert-response`
Submit a response to a duty hour alert.
- **Access:** Private (`ADMIN`, `SUPERADMIN`)
- **Body Payload (JSON):**
```json
{
  "alertType": "8HR", // required. '8HR', '9HR', '10HR', '11HR', '14HR'
  "response": "Understood and monitoring", // required
  "remarks": "Additional optional context" // optional
}
```

#### `GET /shifts/:id/alerts`
Get the alert history for a specific shift.
- **Access:** Private (All roles)
- **Response Payload Example (JSON):**
```json
{
  "success": true,
  "data": {
    "shiftId": "uuid-1234",
    "trainNumber": "12345",
    "signOnDateTime": "2023-10-15T08:00:00Z",
    "currentDutyHours": 8.5,
    "status": "IN_PROGRESS",
    "alertHistory": [
      {
        "type": "8HR", // '7HR', '8HR', '9HR', '10HR', '11HR', '14HR'
        "sentAt": "2023-10-15T16:00:00Z",
        "response": "PLAN_RELIEF", // string or null
        "requiresAction": true // boolean
      }
    ]
  }
}
```

#### `POST /shifts/:id/complete`
Complete a shift with sign-off details.
- **Access:** Private (`ADMIN`, `SUPERADMIN`)
- **Body Payload (JSON):**
```json
{
  "signOffDateTime": "2023-10-15T18:00:00Z", // ISO8601 formatted, required
  "signOffStation": "BCT" // string, required
}
```

---

## 4. Alert Management (`/alerts`)

#### `GET /alerts`
Get all system alert notifications relevant to the authenticated user.
- **Access:** Private (All roles)
- **Response Payload Example (JSON array inside `data`):**
```json
{
  "success": true,
  "data": [
    {
      "id": "notification-uuid",
      "shiftId": "shift-uuid",
      "type": "DUTY_8HR", // 'DUTY_8HR', 'DUTY_10HR', 'DUTY_12HR', 'RELIEF_PLANNED', 'SHIFT_COMPLETED', 'CUSTOM'
      "title": "8 Hour Duty Exceeded",
      "message": "Crew on train 12345 has exceeded 8 hours",
      "status": "PENDING", // 'PENDING', 'SENT', 'ACKNOWLEDGED', 'FAILED'
      "sentAt": "2023-10-15T16:00:00Z",
      "acknowledgedAt": null,
      "responseAction": null,
      "priority": 1,
      "createdAt": "2023-10-15T16:00:00Z",
      "shift": {
        "id": "shift-uuid",
        "trainNumber": "12345",
        "signOnDateTime": "2023-10-15T08:00:00Z"
      }
    }
  ]
}
```

---

## 5. User Management (`/users`)
> [!WARNING]
> All user management endpoints strictly require the `SUPERADMIN` role.

#### `GET /users`
Get all users. Supports filtering.
- **Access:** Private (`SUPERADMIN`)

#### `GET /users/pending-requests`
Get a list of users pending registration approval.
- **Access:** Private (`SUPERADMIN`)

#### `GET /users/:id`
Get a user's details by ID.
- **Access:** Private (`SUPERADMIN`)

#### `POST /users/:id/approve`
Approve a pending user.
- **Access:** Private (`SUPERADMIN`)

#### `POST /users/:id/reject`
Reject a pending user.
- **Access:** Private (`SUPERADMIN`)
- **Body Parameters:**
  - `reason` (string, optional)

#### `PATCH /users/:id/role`
Change a user's role.
- **Access:** Private (`SUPERADMIN`)
- **Body Parameters:**
  - `role` (string: `'USER' | 'ADMIN' | 'SUPERADMIN'`, required)

#### `PATCH /users/:id`
Update user information. All fields are optional.
- **Access:** Private (`SUPERADMIN`)
- **Body Payload (JSON):**
```json
{
  "name": "Jane Doe",
  "email": "jane@railway.com",
  "phone": "+91-9876543210",
  "division": "Northern",
  "designation": "Manager",
  "password": "newSecurePassword123"
}
```

#### `POST /users/:id/activate`
Activate a deactivated user.
- **Access:** Private (`SUPERADMIN`)

#### `POST /users/:id/deactivate`
Deactivate an active user.
- **Access:** Private (`SUPERADMIN`)

#### `DELETE /users/:id`
Delete a user.
- **Access:** Private (`SUPERADMIN`)

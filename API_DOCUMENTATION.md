# Railway Shift Management API Documentation

Base URL: `http://localhost:8080/api/v1`

---

## Authentication Routes

### 1. Register User
**POST** `/auth/register`

Creates a new user account.

#### Request Payload
```json
{
  "employeeId": "EMP001",
  "name": "John Doe",
  "email": "john.doe@railway.com",
  "phone": "+91-9876543210",
  "password": "SecurePass123!",
  "role": "USER",
  "division": "Western Railway",
  "designation": "Station Master"
}
```

#### Validation Rules
- `employeeId`: Required, string, unique
- `name`: Required, string, min 2 characters
- `email`: Required, valid email format, unique
- `phone`: Optional, string
- `password`: Required, min 6 characters
- `role`: Optional, enum: `USER`, `ADMIN`, `SUPERADMIN` (default: `USER`)
- `division`: Optional, string (Railway division/department)
- `designation`: Optional, string (Job designation)

#### Success Response (201 Created)
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "uuid-string",
      "employeeId": "EMP001",
      "name": "John Doe",
      "email": "john.doe@railway.com",
      "phone": "+91-9876543210",
      "role": "USER",
      "status": "INACTIVE",
      "isVerified": false,
      "division": "Western Railway",
      "designation": "Station Master",
      "createdAt": "2025-12-04T13:30:00.000Z",
      "updatedAt": "2025-12-04T13:30:00.000Z",
      "lastLogin": null
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

---

### 2. Login
**POST** `/auth/login`

Authenticates a user and returns tokens.

#### Request Payload
```json
{
  "email": "john.doe@railway.com",
  "password": "SecurePass123!"
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "uuid-string",
      "employeeId": "EMP001",
      "name": "John Doe",
      "email": "john.doe@railway.com",
      "phone": "+91-9876543210",
      "role": "USER",
      "status": "ACTIVE",
      "isVerified": true,
      "division": "Western Railway",
      "designation": "Station Master",
      "lastLogin": "2025-12-04T13:35:00.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

---

### 3. Refresh Token
**POST** `/auth/refresh`

Generates new access token using refresh token.

#### Request Payload
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Token refreshed successfully",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

---

### 4. Get Current User
**GET** `/auth/me`

Returns current authenticated user details.

#### Headers
```
Authorization: Bearer <accessToken>
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "id": "uuid-string",
    "employeeId": "EMP001",
    "name": "John Doe",
    "email": "john.doe@railway.com",
    "phone": "+91-9876543210",
    "role": "USER",
    "status": "ACTIVE",
    "isVerified": true,
    "division": "Western Railway",
    "designation": "Station Master",
    "createdAt": "2025-12-04T13:30:00.000Z",
    "updatedAt": "2025-12-04T13:30:00.000Z",
    "lastLogin": "2025-12-04T13:35:00.000Z"
  }
}
```

---

## Shift Routes

All shift routes require authentication.

### Headers (Required for all shift routes)
```
Authorization: Bearer <accessToken>
```

---

### 1. Create Shift
**POST** `/shifts`

Creates a new shift entry with auto-creation of Staff and Locomotive entities.

#### Request Payload
```json
{
  "trainNumber": "12345",
  "trainName": "Express Train",
  "locomotive": {
    "locomotiveNo": "WAP-7-30456",
    "status": "ACTIVE",
    "autoCreated": true
  },
  "locoPilot": {
    "employeeId": "LP001",
    "name": "Rajesh Kumar",
    "staffType": "LOCO_PILOT",
    "phone": "+91-9876543210",
    "status": "ON_DUTY",
    "autoCreated": true
  },
  "trainManager": {
    "employeeId": "TM001",
    "name": "Suresh Singh",
    "staffType": "TRAIN_MANAGER",
    "phone": "+91-9876543211",
    "status": "ON_DUTY",
    "autoCreated": true
  },
  "trainArrivalDateTime": "2025-12-04T08:30:00.000Z",
  "signOnDateTime": "2025-12-04T08:00:00.000Z",
  "timeOfTO": "2025-12-04T08:45:00.000Z",
  "departureDateTime": "2025-12-04T09:00:00.000Z",
  "signOnStation": "NDLS",
  "section": "Delhi-Mumbai",
  "dutyType": "SP"
}
```

#### Validation Rules
- `trainNumber`: Required, string
- `trainName`: Optional, string
- `locomotive.locomotiveNo`: Required, string
- `locomotive.autoCreated`: Optional, boolean (indicates auto-creation)
- `locoPilot.employeeId`: Required, string, unique
- `locoPilot.name`: Required, string
- `locoPilot.staffType`: Required, enum: `LOCO_PILOT`
- `locoPilot.phone`: Optional, string
- `locoPilot.status`: Optional, enum: `AVAILABLE`, `ON_DUTY`, `ON_LEAVE`, `RELIEVED`, `INACTIVE`
- `locoPilot.autoCreated`: Optional, boolean
- `trainManager.employeeId`: Required, string, unique
- `trainManager.name`: Required, string
- `trainManager.staffType`: Required, enum: `TRAIN_MANAGER`
- `trainManager.phone`: Optional, string
- `trainManager.status`: Optional, enum: `AVAILABLE`, `ON_DUTY`, `ON_LEAVE`, `RELIEVED`, `INACTIVE`
- `trainManager.autoCreated`: Optional, boolean
- `trainArrivalDateTime`: Required, ISO 8601 datetime
- `signOnDateTime`: Required, ISO 8601 datetime
- `timeOfTO`: Optional, ISO 8601 datetime
- `departureDateTime`: Optional, ISO 8601 datetime
- `signOnStation`: Required, string
- `section`: Required, string
- `dutyType`: Required, enum: `SP`, `WR`, `LR`

#### Success Response (201 Created)
```json
{
  "success": true,
  "message": "Shift created successfully",
  "data": {
    "id": "shift-uuid",
    "trainNumber": "12345",
    "trainName": "Express Train",
    "locomotiveId": "loco-uuid",
    "locomotive": {
      "id": "loco-uuid",
      "locomotiveNo": "WAP-7-30456",
      "status": "ACTIVE",
      "autoCreated": true,
      "createdAt": "2025-12-04T13:40:00.000Z",
      "updatedAt": "2025-12-04T13:40:00.000Z"
    },
    "locoPilotId": "pilot-uuid",
    "locoPilot": {
      "id": "pilot-uuid",
      "employeeId": "LP001",
      "name": "Rajesh Kumar",
      "staffType": "LOCO_PILOT",
      "phone": "+91-9876543210",
      "status": "ON_DUTY",
      "autoCreated": true,
      "createdAt": "2025-12-04T13:40:00.000Z",
      "updatedAt": "2025-12-04T13:40:00.000Z"
    },
    "trainManagerId": "manager-uuid",
    "trainManager": {
      "id": "manager-uuid",
      "employeeId": "TM001",
      "name": "Suresh Singh",
      "staffType": "TRAIN_MANAGER",
      "phone": "+91-9876543211",
      "status": "ON_DUTY",
      "autoCreated": true,
      "createdAt": "2025-12-04T13:40:00.000Z",
      "updatedAt": "2025-12-04T13:40:00.000Z"
    },
    "trainArrivalDateTime": "2025-12-04T08:30:00.000Z",
    "signOnDateTime": "2025-12-04T08:00:00.000Z",
    "timeOfTO": "2025-12-04T08:45:00.000Z",
    "departureDateTime": "2025-12-04T09:00:00.000Z",
    "signOffDateTime": null,
    "signOnStation": "NDLS",
    "signOffStation": null,
    "section": "Delhi-Mumbai",
    "dutyType": "SP",
    "dutyHours": null,
    "status": "SCHEDULED",
    "alert7HrSent": false,
    "alert8HrSent": false,
    "alert9HrSent": false,
    "alert10HrSent": false,
    "alert11HrSent": false,
    "alert14HrSent": false,
    "reliefRequired": false,
    "reliefPlanned": false,
    "reliefTime": null,
    "reliefReason": null,
    "createdById": "user-uuid",
    "updatedById": null,
    "createdAt": "2025-12-04T13:40:00.000Z",
    "updatedAt": "2025-12-04T13:40:00.000Z"
  }
}
```

---

### 2. Get All Shifts
**GET** `/shifts`

Retrieves all shifts with optional filtering and pagination.

#### Query Parameters
- `status`: Optional, filter by status (`SCHEDULED`, `IN_PROGRESS`, `COMPLETED`, `RELIEF_PLANNED`, `CANCELLED`)
- `trainNumber`: Optional, filter by train number
- `section`: Optional, filter by section
- `dutyType`: Optional, filter by duty type (`SP`, `WR`, `LR`)
- `fromDate`: Optional, filter from date (ISO 8601)
- `toDate`: Optional, filter to date (ISO 8601)
- `page`: Optional, page number (default: 1)
- `limit`: Optional, items per page (default: 10, max: 100)

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": [
    {
      "id": "shift-uuid",
      "trainNumber": "12345",
      "trainName": "Express Train",
      "locomotive": {
        "locomotiveNo": "WAP-7-30456"
      },
      "locoPilot": {
        "employeeId": "LP001",
        "name": "Rajesh Kumar",
        "phone": "+91-9876543210",
        "staffType": "LOCO_PILOT"
      },
      "trainManager": {
        "employeeId": "TM001",
        "name": "Suresh Singh",
        "phone": "+91-9876543211",
        "staffType": "TRAIN_MANAGER"
      },
      "trainArrivalDateTime": "2025-12-04T08:30:00.000Z",
      "signOnDateTime": "2025-12-04T08:00:00.000Z",
      "departureDateTime": "2025-12-04T09:00:00.000Z",
      "signOnStation": "NDLS",
      "signOffStation": null,
      "section": "Delhi-Mumbai",
      "dutyType": "SP",
      "status": "IN_PROGRESS",
      "dutyHours": null,
      "createdAt": "2025-12-04T13:40:00.000Z",
      "updatedAt": "2025-12-04T13:40:00.000Z"
    }
  ],
  "pagination": {
    "total": 47,
    "page": 1,
    "limit": 10,
    "pages": 5
  }
}
```

---

### 3. Get Shift by ID
**GET** `/shifts/:id`

Retrieves a specific shift by ID with complete details including duty logs.

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "id": "shift-uuid",
    "trainNumber": "12345",
    "trainName": "Express Train",
    "locomotive": {
      "id": "loco-uuid",
      "locomotiveNo": "WAP-7-30456",
      "status": "ACTIVE"
    },
    "locoPilot": {
      "id": "pilot-uuid",
      "employeeId": "LP001",
      "name": "Rajesh Kumar",
      "phone": "+91-9876543210",
      "staffType": "LOCO_PILOT",
      "status": "ON_DUTY"
    },
    "trainManager": {
      "id": "manager-uuid",
      "employeeId": "TM001",
      "name": "Suresh Singh",
      "phone": "+91-9876543211",
      "staffType": "TRAIN_MANAGER",
      "status": "ON_DUTY"
    },
    "trainArrivalDateTime": "2025-12-04T08:30:00.000Z",
    "signOnDateTime": "2025-12-04T08:00:00.000Z",
    "timeOfTO": "2025-12-04T08:45:00.000Z",
    "departureDateTime": "2025-12-04T09:00:00.000Z",
    "signOffDateTime": "2025-12-04T18:00:00.000Z",
    "signOnStation": "NDLS",
    "signOffStation": "BCT",
    "section": "Delhi-Mumbai",
    "dutyType": "SP",
    "dutyHours": 10.0,
    "status": "COMPLETED",
    "alert7HrSent": true,
    "alert7HrSentAt": "2025-12-04T15:00:00.000Z",
    "alert8HrSent": true,
    "alert8HrSentAt": "2025-12-04T16:00:00.000Z",
    "alert8HrResponse": "RELIEF_NOT_REQUIRED",
    "alert9HrSent": true,
    "alert9HrSentAt": "2025-12-04T17:00:00.000Z",
    "alert9HrResponse": "CREW_NOT_BOOKED",
    "reliefRequired": false,
    "reliefPlanned": false,
    "reliefTime": null,
    "reliefReason": null,
    "createdBy": {
      "name": "John Doe",
      "employeeId": "EMP001"
    },
    "updatedBy": {
      "name": "John Doe",
      "employeeId": "EMP001"
    },
    "dutyLogs": [
      {
        "id": "log-uuid-1",
        "logType": "SIGN_ON",
        "logTime": "2025-12-04T08:00:00.000Z",
        "dutyHoursAtLog": 0,
        "remarks": "Sign on recorded",
        "staff": {
          "name": "Rajesh Kumar",
          "employeeId": "LP001"
        }
      },
      {
        "id": "log-uuid-2",
        "logType": "DEPARTURE",
        "logTime": "2025-12-04T09:00:00.000Z",
        "dutyHoursAtLog": 1.0,
        "remarks": "Train departed",
        "staff": {
          "name": "Rajesh Kumar",
          "employeeId": "LP001"
        }
      },
      {
        "id": "log-uuid-3",
        "logType": "ALERT_7HR",
        "logTime": "2025-12-04T15:00:00.000Z",
        "dutyHoursAtLog": 7.0,
        "remarks": "7-hour duty alert sent"
      },
      {
        "id": "log-uuid-4",
        "logType": "RELEASE",
        "logTime": "2025-12-04T18:00:00.000Z",
        "dutyHoursAtLog": 10.0,
        "remarks": "Shift completed"
      }
    ],
    "notifications": [
      {
        "id": "notif-uuid-1",
        "type": "DUTY_8HR",
        "title": "8-Hour Duty Alert",
        "message": "Crew has completed 8 hours of duty",
        "dutyHours": 8.0,
        "status": "ACKNOWLEDGED",
        "sentAt": "2025-12-04T16:00:00.000Z",
        "acknowledgedAt": "2025-12-04T16:05:00.000Z",
        "responseAction": "RELIEF_NOT_REQUIRED"
      }
    ],
    "createdAt": "2025-12-04T13:40:00.000Z",
    "updatedAt": "2025-12-04T18:05:00.000Z"
  }
}
```

---

### 4. Update Shift
**PATCH** `/shifts/:id`

Updates an existing shift.

#### Request Payload (All fields optional)
```json
{
  "trainName": "Updated Train Name",
  "timeOfTO": "2025-12-04T08:50:00.000Z",
  "departureDateTime": "2025-12-04T09:15:00.000Z",
  "signOffStation": "BCT",
  "signOffDateTime": "2025-12-04T18:00:00.000Z",
  "status": "COMPLETED",
  "reliefRequired": false,
  "reliefPlanned": false,
  "reliefTime": null,
  "reliefReason": null
}
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Shift updated successfully",
  "data": {
    "id": "shift-uuid",
    "trainNumber": "12345",
    "trainName": "Updated Train Name",
    "status": "COMPLETED",
    "signOffStation": "BCT",
    "signOffDateTime": "2025-12-04T18:00:00.000Z",
    "dutyHours": 10.0,
    "updatedAt": "2025-12-04T18:05:00.000Z"
  }
}
```

---

### 5. Delete Shift
**DELETE** `/shifts/:id`

Deletes a shift (requires ADMIN or SUPERADMIN role).

#### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Shift deleted successfully"
}
```

---

### 6. Get Active Shifts
**GET** `/shifts/active`

Retrieves all currently active shifts (IN_PROGRESS status).

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": [
    {
      "id": "shift-uuid",
      "trainNumber": "12345",
      "trainName": "Express Train",
      "locoPilot": {
        "name": "Rajesh Kumar",
        "phone": "+91-9876543210"
      },
      "trainManager": {
        "name": "Suresh Singh",
        "phone": "+91-9876543211"
      },
      "signOnDateTime": "2025-12-04T08:00:00.000Z",
      "currentDutyHours": 5.5,
      "status": "IN_PROGRESS"
    }
  ]
}
```

---

### 7. Get Shift Statistics
**GET** `/shifts/stats`

Retrieves shift statistics and analytics.

#### Query Parameters
- `fromDate`: Optional, start date (ISO 8601)
- `toDate`: Optional, end date (ISO 8601)

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": {
    "totalShifts": 150,
    "activeShifts": 12,
    "completedShifts": 130,
    "cancelledShifts": 8,
    "averageDutyHours": 9.2,
    "byStatus": {
      "SCHEDULED": 5,
      "IN_PROGRESS": 12,
      "COMPLETED": 130,
      "RELIEF_PLANNED": 3,
      "CANCELLED": 8
    },
    "byDutyType": {
      "SP": 80,
      "WR": 45,
      "LR": 25
    },
    "bySection": {
      "Delhi-Mumbai": 60,
      "Mumbai-Delhi": 55,
      "Delhi-Kolkata": 35
    },
    "alertStatistics": {
      "total7HrAlerts": 45,
      "total8HrAlerts": 32,
      "total9HrAlerts": 18,
      "total11HrAlerts": 8,
      "total14HrAlerts": 2
    }
  }
}
```

---

## Staff Routes

### 1. Get All Staff
**GET** `/staff`

Retrieves all staff members with optional filtering.

#### Query Parameters
- `staffType`: Optional, filter by type (`LOCO_PILOT`, `TRAIN_MANAGER`)
- `status`: Optional, filter by status (`AVAILABLE`, `ON_DUTY`, `ON_LEAVE`, `RELIEVED`, `INACTIVE`)
- `employeeId`: Optional, filter by employee ID
- `name`: Optional, search by name
- `page`: Optional, page number (default: 1)
- `limit`: Optional, items per page (default: 10)

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": [
    {
      "id": "staff-uuid",
      "employeeId": "LP001",
      "name": "Rajesh Kumar",
      "staffType": "LOCO_PILOT",
      "phone": "+91-9876543210",
      "email": "rajesh.kumar@railway.com",
      "homeStation": "NDLS",
      "status": "AVAILABLE",
      "autoCreated": false,
      "createdAt": "2025-12-04T10:00:00.000Z",
      "updatedAt": "2025-12-04T10:00:00.000Z"
    }
  ]
}
```

---

### 2. Create Staff
**POST** `/staff`

Creates a new staff member.

#### Request Payload
```json
{
  "employeeId": "LP002",
  "name": "Suresh Singh",
  "staffType": "LOCO_PILOT",
  "phone": "+91-9876543211",
  "email": "suresh.singh@railway.com",
  "homeStation": "BCT",
  "status": "AVAILABLE"
}
```

---

## Locomotive Routes

### 1. Get All Locomotives
**GET** `/locomotives`

Retrieves all locomotives with optional filtering.

#### Query Parameters
- `locomotiveNo`: Optional, filter by locomotive number
- `status`: Optional, filter by status
- `page`: Optional, page number (default: 1)
- `limit`: Optional, items per page (default: 10)

#### Success Response (200 OK)
```json
{
  "success": true,
  "data": [
    {
      "id": "loco-uuid",
      "locomotiveNo": "WAP-7-30456",
      "status": "ACTIVE",
      "autoCreated": false,
      "createdAt": "2025-12-04T10:00:00.000Z",
      "updatedAt": "2025-12-04T10:00:00.000Z"
    }
  ]
}
```

---

## Error Responses

### Common Error Codes

#### 400 Bad Request
```json
{
  "success": false,
  "statusCode": 400,
  "message": "Validation failed",
  "errors": [
    {
      "field": "trainNumber",
      "message": "Train number is required"
    }
  ]
}
```

#### 401 Unauthorized
```json
{
  "success": false,
  "statusCode": 401,
  "message": "Invalid or expired token"
}
```

#### 403 Forbidden
```json
{
  "success": false,
  "statusCode": 403,
  "message": "Insufficient permissions"
}
```

#### 404 Not Found
```json
{
  "success": false,
  "statusCode": 404,
  "message": "Resource not found"
}
```

#### 500 Internal Server Error
```json
{
  "success": false,
  "statusCode": 500,
  "message": "Internal server error"
}
```

---

## Data Models

### User Model
```typescript
{
  id: string (UUID)
  employeeId: string (unique)
  name: string
  email: string (unique)
  phone?: string
  role: "USER" | "ADMIN" | "SUPERADMIN"
  status: "ACTIVE" | "INACTIVE" | "SUSPENDED"
  isVerified: boolean
  verifiedAt?: DateTime
  verifiedBy?: string
  rejectedAt?: DateTime
  rejectedBy?: string
  rejectionReason?: string
  division?: string
  designation?: string
  createdAt: DateTime
  updatedAt: DateTime
  lastLogin?: DateTime
}
```

### Staff Model
```typescript
{
  id: string (UUID)
  employeeId: string (unique)
  name: string
  staffType: "LOCO_PILOT" | "TRAIN_MANAGER"
  phone?: string
  email?: string
  homeStation?: string
  status: "AVAILABLE" | "ON_DUTY" | "ON_LEAVE" | "RELIEVED" | "INACTIVE"
  autoCreated: boolean
  createdAt: DateTime
  updatedAt: DateTime
}
```

### Locomotive Model
```typescript
{
  id: string (UUID)
  locomotiveNo: string (unique)
  status?: string
  autoCreated: boolean
  createdAt: DateTime
  updatedAt: DateTime
}
```

### Shift Model
```typescript
{
  id: string (UUID)
  trainNumber: string
  trainName?: string
  locomotiveId: string (UUID)
  locoPilotId: string (UUID)
  trainManagerId: string (UUID)
  trainArrivalDateTime: DateTime
  signOnDateTime: DateTime
  timeOfTO?: DateTime
  departureDateTime?: DateTime
  signOffDateTime?: DateTime
  signOnStation: string
  signOffStation?: string
  section: string
  dutyType: "SP" | "WR" | "LR"
  dutyHours?: number
  status: "SCHEDULED" | "IN_PROGRESS" | "COMPLETED" | "RELIEF_PLANNED" | "CANCELLED"
  alert7HrSent: boolean
  alert8HrSent: boolean
  alert9HrSent: boolean
  alert10HrSent: boolean
  alert11HrSent: boolean
  alert14HrSent: boolean
  reliefRequired: boolean
  reliefPlanned: boolean
  reliefTime?: DateTime
  reliefReason?: string
  createdById: string (UUID)
  updatedById?: string (UUID)
  createdAt: DateTime
  updatedAt: DateTime
}
```

---

## Notes

1. **Auto-Creation**: The API supports auto-creation of Staff and Locomotive entities when creating shifts. Set `autoCreated: true` in the payload.

2. **DateTime Format**: All datetime fields use ISO 8601 format (e.g., "2025-12-04T08:30:00.000Z").

3. **Pagination**: Most list endpoints support pagination with `page` and `limit` parameters.

4. **Authentication**: All routes except auth routes require a valid JWT token in the Authorization header.

5. **Role-Based Access**: Some operations require specific roles (ADMIN, SUPERADMIN).

6. **Validation**: The API performs comprehensive validation on all input data.

7. **Alert System**: The system automatically tracks and sends alerts at 7, 8, 9, 10, 11, and 14-hour intervals.
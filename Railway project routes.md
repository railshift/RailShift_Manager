
**Table** **of** **Contents**

> 1\. Authentication Routes
>
> 2\. Shift Management Routes
>
> 3\. Dashboard Routes
>
> 4\. User Management Routes
>
> 5\. Common Response Formats
>
> 6\. Error Handling

**Authentication** **Routes**

Base Path: /api/v1/auth

All authentication routes are public except /auth/me and /auth/logout
which require authentication.

**1.** **Register** **New** **User**

> POST /api/v1/auth/register Content-Type: application/json

**Description:** Register a new user account. Account is inactive until
approved by SUPERADMIN.

**Request** **Body:**

> {
>
> "employeeId": "EMP001", "name": "John Doe",
>
> "email": "john.doe@railway.com", "phone": "+91-9876543210",
> "password": "SecurePass123!", "division": "Operations", "designation":
> "Shift Coordinator", "role": "ADMIN"
>
> }

**Validation** **Rules:**

> employeeId : Required, unique, string
>
> name : Required, min 2 characters
>
> email : Required, valid email format, unique
>
> phone : Optional, string
>
> password : Required, min 6 characters
>
> division : Optional, string
>
> designation : Optional, string
>
> role : Optional, enum: USER , ADMIN , SUPERADMIN (default: USER )

**Success** **Response** **(201** **Created):**

> {
>
> "success": true,
>
> "message": "Registration successful. Your account is pending approval
> by administrator.", "data": {
>
> "user": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe",
>
> "email": "john.doe@railway.com", "phone": "+91-9876543210", "role":
> "ADMIN",
>
> "status": "INACTIVE", "isVeriﬁed": false, "division": "Operations",
>
> "designation": "Shift Coordinator", "createdAt":
> "2026-03-25T10:30:00.000Z"
>
> } }
>
> }

**Error** **Response** **(400** **Bad** **Request):**

> {
>
> "success": false,
>
> "message": "Validation failed", "errors": \[
>
> {
>
> "ﬁeld": "email",
>
> "message": "Email already exists" }
>
> \] }

**Rate** **Limit:** 5 requests per 15 minutes per IP

**2.** **Login**

> POST /api/v1/auth/login Content-Type: application/json

**Description:** Authenticate user and receive JWT tokens.

**Request** **Body:**

> {
>
> "email": "john.doe@railway.com", "password": "SecurePass123!"
>
> }

**Validation** **Rules:**

> email : Required, valid email format
>
> password : Required, non-empty string

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Login successful", "data": {
>
> "user": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe",
>
> "email": "john.doe@railway.com", "phone": "+91-9876543210", "role":
> "ADMIN",
>
> "status": "ACTIVE", "division": "Operations",
>
> "createdAt": "2025-11-24T13:30:00.000Z", "lastLogin":
> "2026-03-25T10:35:00.000Z"
>
> }, "tokens": {
>
> "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
> "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
>
> } }
>
> }

**Error** **Response** **(401** **Unauthorized):**

> {
>
> "success": false,
>
> "message": "Invalid email or password" }

**Error** **Response** **(403** **Forbidden):**

> {
>
> "success": false,
>
> "message": "Account is inactive or suspended" }

**Rate** **Limit:** 10 requests per 15 minutes per IP

**3.** **Get** **Current** **User**

> GET /api/v1/auth/me
>
> Authorization: Bearer \<accessToken\>

**Description:** Retrieve details of the currently authenticated user.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe",
>
> "email": "john.doe@railway.com", "phone": "+91-9876543210", "role":
> "ADMIN",
>
> "status": "ACTIVE", "division": "Operations",
>
> "designation": "Shift Coordinator", "priority": 1,
>
> "isVeriﬁed": true,
>
> "veriﬁedAt": "2025-11-27T10:00:00.000Z", "createdAt":
> "2025-11-24T13:30:00.000Z", "lastLogin": "2026-03-25T10:35:00.000Z"
>
> } }

**Error** **Response** **(401** **Unauthorized):**

> {
>
> "success": false,
>
> "message": "No token provided or invalid token" }

**4.** **Refresh** **Access** **Token**

> POST /api/v1/auth/refresh
>
> Content-Type: application/json

**Description:** Generate a new access token using refresh token when
access token expires.

**Request** **Body:**

> {
>
> "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }

**Validation** **Rules:**

> refreshToken : Required, non-empty string

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Token refreshed successfully", "data": {
>
> "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
> "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
>
> } }

**Error** **Response** **(401** **Unauthorized):**

> {
>
> "success": false,
>
> "message": "Invalid or expired refresh token" }

**5.** **Logout**

> POST /api/v1/auth/logout Authorization: Bearer \<accessToken\>

**Description:** Logout the current user. Client should delete stored
tokens.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Logout successful" }

**6.** **Forgot** **Password**

> POST /api/v1/auth/forgot-password Content-Type: application/json

**Description:** Request password reset OTP. OTP will be sent to the
registered email.

**Request** **Body:**

> {
>
> "email": "john.doe@railway.com" }

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "OTP sent to your registered email" }

**Error** **Response** **(404** **Not** **Found):**

> {
>
> "success": false,
>
> "message": "User not found" }

**Rate** **Limit:** 3 requests per 15 minutes per IP

**7.** **Reset** **Password**

> POST /api/v1/auth/reset-password Content-Type: application/json

**Description:** Reset password using OTP received via email.

**Request** **Body:**

> {
>
> "email": "john.doe@railway.com", "otp": "123456",
>
> "newPassword": "NewSecurePass123!" }

**Validation** **Rules:**

> email : Required, valid email format
>
> otp : Required, 6 digits
>
> newPassword : Required, min 6 characters

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Password reset successful" }

**Shift** **Management** **Routes**

Base Path: /api/v1/shifts

**Authentication** **Required:** All routes require Bearer token

**1.** **Create** **New** **Shift**

> POST /api/v1/shifts
>
> Authorization: Bearer \<accessToken\> Content-Type: application/json

**Permission:** ADMIN, SUPERADMIN

**Description:** Create a new shift and start duty hour tracking.

**Request** **Body:**

> {
>
> "trainNumber": "12345", "trainName": "Rajdhani Express",
> "locomotiveNo": "WAP-7-30456", "locoPilot": {
>
> "employeeId": "LP001", "name": "Rajesh Kumar", "phone":
> "+91-9876543210"
>
> }, "trainManager": {
>
> "employeeId": "TM001", "name": "Suresh Singh", "phone":
> "+91-9876543211"
>
> },
>
> "trainArrivalDateTime": "2026-03-25T08:30:00.000Z", "signOnDateTime":
> "2026-03-25T08:00:00.000Z", "timeOfTO": "2026-03-25T08:45:00.000Z",
> "departureDateTime": "2026-03-25T09:00:00.000Z", "signOnStation":
> "NDLS",
>
> "section": "Delhi-Mumbai", "dutyType": "SP"
>
> }

**Validation** **Rules:**

> trainNumber : Required, string
>
> trainName : Optional, string
>
> locomotiveNo : Required, string
>
> locoPilot.employeeId : Required, string
>
> locoPilot.name : Required, string
>
> locoPilot.phone : Optional, valid phone number
>
> trainManager.employeeId : Required, string
>
> trainManager.name : Required, string
>
> trainManager.phone : Optional, valid phone number
>
> trainArrivalDateTime : Required, ISO 8601 datetime
>
> signOnDateTime : Required, ISO 8601 datetime
>
> timeOfTO : Optional, ISO 8601 datetime
>
> departureDateTime : Optional, ISO 8601 datetime
>
> signOnStation : Required, string
>
> section : Required, string
>
> dutyType : Required, enum: SP , WR , LR

**Success** **Response** **(201** **Created):**

> {
>
> "success": true,
>
> "message": "Shift created successfully", "data": {
>
> "id": "shift-550e8400-e29b-41d4-a716-446655440000", "trainNumber":
> "12345",
>
> "trainName": "Rajdhani Express", "locomotiveNo": "WAP-7-30456",
> "locomotiveId": "loco-550e8400", "status": "IN_PROGRESS", "dutyType":
> "SP",
>
> "section": "Delhi-Mumbai",
>
> "trainArrivalDateTime": "2026-03-25T08:30:00.000Z", "signOnDateTime":
> "2026-03-25T08:00:00.000Z", "timeOfTO": "2026-03-25T08:45:00.000Z",
> "departureDateTime": "2026-03-25T09:00:00.000Z", "signOnStation":
> "NDLS",
>
> "dutyHours": null, "reliefRequired": false, "reliefPlanned": false,
> "locoPilot": {
>
> "id": "pilot-550e8400", "employeeId": "LP001", "name": "Rajesh Kumar",
> "phone": "+91-9876543210", "status": "ON_DUTY"
>
> }, "trainManager": {
>
> "id": "manager-550e8400", "employeeId": "TM001", "name": "Suresh
> Singh", "phone": "+91-9876543211", "status": "ON_DUTY"
>
> },
>
> "createdAt": "2026-03-25T08:00:00.000Z", "updatedAt":
> "2026-03-25T08:00:00.000Z"
>
> } }

**Rate** **Limit:** 20 requests per hour per user

**2.** **List** **All** **Shifts**

> GET /api/v1/shifts?status=IN_PROGRESS&page=1&limit=10 Authorization:
> Bearer \<accessToken\>

**Permission:** All authenticated users

**Description:** Retrieve all shifts with optional ﬁltering and
pagination.

**Query** **Parameters:**

> status : Optional, enum: SCHEDULED , IN_PROGRESS , COMPLETED ,
> RELIEF_PLANNED , CANCELLED
>
> trainNumber : Optional, string
>
> section : Optional, string
>
> dutyType : Optional, enum: SP , WR , LR
>
> fromDate : Optional, ISO 8601 date
>
> toDate : Optional, ISO 8601 date
>
> page : Optional, default: 1
>
> limit : Optional, default: 10, max: 100

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "shifts": \[ {
>
> "id": "shift-550e8400-e29b-41d4-a716-446655440000", "trainNumber":
> "12345",
>
> "trainName": "Rajdhani Express", "locomotiveNo": "WAP-7-30456",
> "status": "IN_PROGRESS", "section": "Delhi-Mumbai", "dutyType": "SP",
>
> "trainArrivalDateTime": "2026-03-25T08:30:00.000Z", "signOnDateTime":
> "2026-03-25T08:00:00.000Z", "currentDutyHours": 5.75,
>
> "reliefRequired": false, "reliefPlanned": false, "locoPilot": {
>
> "id": "pilot-550e8400", "employeeId": "LP001", "name": "Rajesh Kumar"
>
> }, "trainManager": {
>
> "id": "manager-550e8400", "employeeId": "TM001", "name": "Suresh
> Singh"
>
> },
>
> "createdAt": "2026-03-25T08:00:00.000Z" }
>
> \], "pagination": {
>
> "page": 1, "limit": 10, "total": 50, "totalPages": 5
>
> } }
>
> }

**3.** **Get** **Shift** **by** **ID**

> GET /api/v1/shifts/:id
>
> Authorization: Bearer \<accessToken\>

**Permission:** All authenticated users

**Description:** Retrieve detailed information about a speciﬁc shift.

**Path** **Parameters:**

> id : Required, UUID of the shift

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "id": "shift-550e8400-e29b-41d4-a716-446655440000", "trainNumber":
> "12345",
>
> "trainName": "Rajdhani Express", "locomotiveNo": "WAP-7-30456",
> "locomotiveId": "loco-550e8400", "status": "IN_PROGRESS", "dutyType":
> "SP",
>
> "section": "Delhi-Mumbai",
>
> "trainArrivalDateTime": "2026-03-25T08:30:00.000Z", "signOnDateTime":
> "2026-03-25T08:00:00.000Z", "timeOfTO": "2026-03-25T08:45:00.000Z",
> "departureDateTime": "2026-03-25T09:00:00.000Z", "signOﬀDateTime":
> null,
>
> "signOnStation": "NDLS", "signOﬀStation": null, "dutyHours": null,
> "reliefRequired": false, "reliefPlanned": false, "reliefTime": null,
> "reliefReason": null, "alert7HrSent": false, "alert8HrSent": true,
>
> "alert8HrResponse": "PLAN_RELIEF", "alert9HrSent": true,
> "alert9HrResponse": "CREW_RELIEVED", "locoPilot": {
>
> "id": "pilot-550e8400", "employeeId": "LP001", "name": "Rajesh Kumar",
> "phone": "+91-9876543210", "status": "ON_DUTY"
>
> }, "trainManager": {
>
> "id": "manager-550e8400", "employeeId": "TM001", "name": "Suresh
> Singh", "phone": "+91-9876543211", "status": "ON_DUTY"
>
> },
>
> "createdAt": "2026-03-25T08:00:00.000Z", "updatedAt":
> "2026-03-25T10:00:00.000Z"
>
> } }

**Error** **Response** **(404** **Not** **Found):**

> {
>
> "success": false,
>
> "message": "Shift not found" }

**4.** **Update** **Shift**

> PATCH /api/v1/shifts/:id Authorization: Bearer \<accessToken\>
> Content-Type: application/json

**Permission:** ADMIN, SUPERADMIN

**Description:** Update shift details (all ﬁelds optional).

**Request** **Body** **(example):**

> {
>
> "timeOfTO": "2026-03-25T08:50:00.000Z", "departureDateTime":
> "2026-03-25T09:10:00.000Z", "section": "Delhi-Mumbai-Bangalore",
>
> "dutyType": "WR", "reliefPlanned": true, "reliefReason": "Crew
> rotation"
>
> }

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Shift updated successfully", "data": {
>
> "id": "shift-550e8400-e29b-41d4-a716-446655440000", "trainNumber":
> "12345",
>
> "status": "IN_PROGRESS",
>
> "section": "Delhi-Mumbai-Bangalore", "dutyType": "WR",
>
> "timeOfTO": "2026-03-25T08:50:00.000Z", "departureDateTime":
> "2026-03-25T09:10:00.000Z", "reliefPlanned": true,
>
> "reliefReason": "Crew rotation", "updatedAt":
> "2026-03-25T10:05:00.000Z"
>
> } }

**5.** **Complete** **Shift**

> POST /api/v1/shifts/:id/complete Authorization: Bearer \<accessToken\>
> Content-Type: application/json

**Permission:** ADMIN, SUPERADMIN

**Description:** Mark a shift as completed with sign-oﬀ details.

**Request** **Body:**

> {
>
> "signOﬀDateTime": "2026-03-25T16:30:00.000Z", "signOﬀStation":
> "MUMBAI"
>
> }

**Validation** **Rules:**

> signOﬀDateTime : Required, ISO 8601 datetime
>
> signOﬀStation : Required, string

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Shift completed successfully", "data": {
>
> "id": "shift-550e8400-e29b-41d4-a716-446655440000", "trainNumber":
> "12345",
>
> "status": "COMPLETED",
>
> "signOﬀDateTime": "2026-03-25T16:30:00.000Z", "signOﬀStation":
> "MUMBAI",
>
> "dutyHours": 8.5,
>
> "updatedAt": "2026-03-25T16:30:00.000Z" }
>
> }

**6.** **Delete** **Shift**

> DELETE /api/v1/shifts/:id Authorization: Bearer \<accessToken\>

**Permission:** SUPERADMIN only

**Description:** Delete a shift (only SUPERADMIN can delete).

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Shift deleted successfully" }

**Error** **Response** **(403** **Forbidden):**

> {
>
> "success": false,
>
> "message": "You do not have permission to delete shifts" }

**7.** **Get** **Active** **Shifts** **Summary**

> GET /api/v1/shifts/active/summary Authorization: Bearer
> \<accessToken\>

**Permission:** All authenticated users

**Description:** Get summary statistics of all active shifts.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "totalActiveShifts": 15, "shiftsWithAlerts": 5,
> "shiftsNearingDutyLimit": 8, "averageDutyHours": 6.5,
> "dutyLimitExceeded": 2, "recentAlerts": \[
>
> {
>
> "shiftId": "shift-550e8400", "trainNumber": "12345", "alert": "8HR",
>
> "time": "2026-03-25T16:00:00.000Z"
>
> } \]
>
> } }

**8.** **Submit** **Alert** **Response**

> POST /api/v1/shifts/:id/alert-response Authorization: Bearer
> \<accessToken\> Content-Type: application/json

**Permission:** ADMIN, SUPERADMIN

**Description:** Submit response to duty hour alerts (8HR, 9HR, 10HR,
11HR, 14HR).

**Request** **Body:**

> {
>
> "alertType": "8HR", "response": "PLAN_RELIEF",
>
> "remarks": "Relief crew will arrive within 2 hours" }

**Validation** **Rules:**

> alertType : Required, enum: 8HR , 9HR , 10HR , 11HR , 14HR
>
> response : Required, string (varies by alert type)
>
> remarks : Optional, string

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "Alert response recorded", "data": {
>
> "shiftId": "shift-550e8400", "alertType": "8HR", "response":
> "PLAN_RELIEF",
>
> "recordedAt": "2026-03-25T16:05:00.000Z" }
>
> }

**9.** **Get** **Shift** **Alert** **History**

> GET /api/v1/shifts/:id/alerts Authorization: Bearer \<accessToken\>

**Permission:** All authenticated users

**Description:** Retrieve complete alert history for a shift.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "shiftId": "shift-550e8400", "trainNumber": "12345", "alerts": \[
>
> {
>
> "alertType": "8HR",
>
> "sentAt": "2026-03-25T16:00:00.000Z", "response": "PLAN_RELIEF",
>
> "responseAt": "2026-03-25T16:05:00.000Z" },
>
> {
>
> "alertType": "9HR",
>
> "sentAt": "2026-03-25T17:00:00.000Z", "response": "CREW_RELIEVED",
> "responseAt": "2026-03-25T17:15:00.000Z"
>
> } \]
>
> } }

**Dashboard** **Routes**

Base Path: /api/v1/dashboard

**Authentication** **Required:** All routes require Bearer token

**1.** **Get** **Dashboard** **Statistics**

> GET /api/v1/dashboard/stats Authorization: Bearer \<accessToken\>

**Description:** Get comprehensive dashboard statistics.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "totalShifts": 150, "activeShifts": 12, "completedShifts": 135,
> "cancelledShifts": 3, "averageDutyHours": 7.8,
> "shiftsExceedingDutyLimit": 5, "pendingAlertResponses": 2,
> "reliefPlannedCount": 3,
>
> "topTrainNumbers": \["12345", "54321", "98765"\], "topStations":
> \["NDLS", "MUMBAI", "BANGALORE"\], "lastUpdated":
> "2026-03-25T10:30:00.000Z"
>
> } }

**2.** **Get** **Recent** **Activities**

> GET /api/v1/dashboard/recent-activities?limit=20&oﬀset=0&type=SIGN_ON
> Authorization: Bearer \<accessToken\>

**Description:** Get recent activities/duty logs with ﬁltering.

**Query** **Parameters:**

> limit : Optional, default: 10, max: 100
>
> oﬀset : Optional, default: 0
>
> type : Optional, ﬁlter by activity type (SIGN_ON, SIGN_OFF, ALERT_8HR,
> ALERT_9HR, etc.)

**Valid** **Activity** **Types:**

> SIGN_ON, SIGN_OFF
>
> ALERT_7HR, ALERT_8HR, ALERT_9HR, ALERT_10HR, ALERT_11HR, ALERT_14HR
>
> RELIEF_PLANNED, RELIEF_NOT_REQUIRED, CREW_RELIEVED, CREW_NOT_BOOKED
>
> KEEP_ON_DUTY, CREW_ALREADY_RELIEVED, RELEASE

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "activities": \[ {
>
> "id": "log-550e8400", "shiftId": "shift-550e8400", "trainNumber":
> "12345",
>
> "staﬀName": "Rajesh Kumar", "staﬀType": "LOCO_PILOT", "logType":
> "SIGN_ON",
>
> "logTime": "2026-03-25T08:00:00.000Z", "dutyHoursAtLog": 0,
>
> "remarks": null },
>
> {
>
> "id": "log-550e8401", "shiftId": "shift-550e8400", "trainNumber":
> "12345", "staﬀName": "Rajesh Kumar", "staﬀType": "LOCO_PILOT",
> "logType": "ALERT_8HR",
>
> "logTime": "2026-03-25T16:00:00.000Z", "dutyHoursAtLog": 8,
>
> "remarks": "Relief crew informed" }
>
> \], "pagination": {
>
> "oﬀset": 0, "limit": 20, "total": 150
>
> } }
>
> }

**3.** **Get** **Shift** **Trends**

> GET /api/v1/dashboard/trends?days=30 Authorization: Bearer
> \<accessToken\>

**Description:** Get shift trends for charts over last N days.

**Query** **Parameters:**

> days : Optional, default: 7, max: 90

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "trends": \[ {
>
> "date": "2026-02-24", "shiftsCreated": 12, "shiftsCompleted": 10,
> "averageDutyHours": 8.1, "shiftsExceedingLimit": 2,
>
> "reliefRequired": 3 },
>
> {
>
> "date": "2026-02-25", "shiftsCreated": 15, "shiftsCompleted": 14,
> "averageDutyHours": 7.9, "shiftsExceedingLimit": 1, "reliefRequired":
> 2
>
> } \],
>
> "summary": { "periodDays": 30, "totalShifts": 425,
>
> "averageDailyShifts": 14.17, "peakDay": "2026-03-15", "peakShifts": 18
>
> } }
>
> }

**4.** **Get** **Alerts** **Summary**

> GET /api/v1/dashboard/alerts-summary Authorization: Bearer
> \<accessToken\>

**Description:** Get summary of active and pending alerts.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "activeAlerts": { "alert8Hr": 3, "alert9Hr": 2, "alert10Hr": 1,
> "alert11Hr": 0, "alert14Hr": 0
>
> },
>
> "pendingResponses": 4, "recentAlerts": \[
>
> {
>
> "shiftId": "shift-550e8400", "trainNumber": "12345", "alert": "8HR",
>
> "sentAt": "2026-03-25T16:00:00.000Z", "pendingSince": "30 minutes",
> "locoPilot": "Rajesh Kumar"
>
> }
>
> \],
>
> "reliefPlanned": 2, "reliefNotRequired": 1,
>
> "lastUpdated": "2026-03-25T10:30:00.000Z" }
>
> }

**User** **Management** **Routes**

Base Path: /api/v1/users

**Authentication** **Required:** All routes require Bearer token +
SUPERADMIN role

**1.** **Get** **All** **Users**

> GET /api/v1/users?status=ACTIVE&role=ADMIN&page=1&limit=10
> Authorization: Bearer \<accessToken\>

**Permission:** SUPERADMIN only

**Description:** Get all users with optional ﬁltering.

**Query** **Parameters:**

> status : Optional, enum: ACTIVE , INACTIVE , SUSPENDED
>
> role : Optional, enum: USER , ADMIN , SUPERADMIN
>
> division : Optional, string
>
> page : Optional, default: 1
>
> limit : Optional, default: 10, max: 100

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "users": \[ {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe",
>
> "email": "john.doe@railway.com", "phone": "+91-9876543210", "role":
> "ADMIN",
>
> "status": "ACTIVE", "division": "Operations",
>
> "designation": "Shift Coordinator", "priority": 1,
>
> "isVeriﬁed": true,
>
> "veriﬁedAt": "2025-11-27T10:00:00.000Z", "createdAt":
> "2025-11-24T13:30:00.000Z", "lastLogin": "2026-03-25T10:35:00.000Z"
>
> } \],
>
> "pagination": { "page": 1, "limit": 10, "total": 45, "totalPages": 5
>
> } }
>
> }

**2.** **Get** **Pending** **User** **Requests**

> GET /api/v1/users/pending-requests Authorization: Bearer
> \<accessToken\>

**Permission:** SUPERADMIN only

**Description:** Get list of pending user registration/approval
requests.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "pendingRequests": \[ {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP002",
>
> "name": "Jane Smith",
>
> "email": "jane.smith@railway.com", "phone": "+91-9876543211", "role":
> "USER",
>
> "division": "Traﬃc", "designation": "Station Master",
>
> "requestedAt": "2026-03-24T15:30:00.000Z", "status": "INACTIVE"
>
> } \],
>
> "totalPending": 3 }
>
> }

**3.** **Get** **User** **by** **ID**

> GET /api/v1/users/:id
>
> Authorization: Bearer \<accessToken\>

**Permission:** SUPERADMIN only

**Description:** Get detailed information of a speciﬁc user.

**Path** **Parameters:**

> id : Required, UUID of the user

**Success** **Response** **(200** **OK):**

> {
>
> "success": true, "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe",
>
> "email": "john.doe@railway.com", "phone": "+91-9876543210", "role":
> "ADMIN",
>
> "status": "ACTIVE", "division": "Operations",
>
> "designation": "Shift Coordinator", "priority": 1,
>
> "isVeriﬁed": true,
>
> "veriﬁedAt": "2025-11-27T10:00:00.000Z", "veriﬁedBy": "SUPERADMIN001",
> "createdAt": "2025-11-24T13:30:00.000Z", "lastLogin":
> "2026-03-25T10:35:00.000Z"
>
> } }

**4.** **Approve** **User**

> POST /api/v1/users/:id/approve Authorization: Bearer \<accessToken\>
> Content-Type: application/json

**Permission:** SUPERADMIN only

**Description:** Approve a pending user registration.

**Request** **Body:**

> {}

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User approved successfully", "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe",
>
> "email": "john.doe@railway.com", "status": "ACTIVE",
>
> "isVeriﬁed": true,
>
> "veriﬁedAt": "2026-03-25T10:45:00.000Z" }
>
> }

**5.** **Reject** **User**

> POST /api/v1/users/:id/reject Authorization: Bearer \<accessToken\>
> Content-Type: application/json

**Permission:** SUPERADMIN only

**Description:** Reject a pending user registration.

**Request** **Body:**

> {
>
> "reason": "Invalid employee ID" }

**Validation** **Rules:**

> reason : Optional, string

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User rejected successfully", "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "status": "INACTIVE",
>
> "rejectedAt": "2026-03-25T10:50:00.000Z", "rejectionReason": "Invalid
> employee ID"
>
> } }

**6.** **Change** **User** **Role**

> PATCH /api/v1/users/:id/role Authorization: Bearer \<accessToken\>
> Content-Type: application/json

**Permission:** SUPERADMIN only

**Description:** Change user role (USER, ADMIN, SUPERADMIN).

**Request** **Body:**

> {
>
> "role": "ADMIN" }

**Validation** **Rules:**

> role : Required, enum: USER , ADMIN , SUPERADMIN

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User role updated", "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "name": "John Doe", "role": "ADMIN",
>
> "updatedAt": "2026-03-25T10:55:00.000Z" }
>
> }

**7.** **Update** **User**

> PATCH /api/v1/users/:id Authorization: Bearer \<accessToken\>
>
> Content-Type: application/json

**Permission:** SUPERADMIN only

**Description:** Update user details (all ﬁelds optional).

**Request** **Body** **(example):**

> {
>
> "phone": "+91-9876543210", "division": "Traﬃc", "designation": "Traﬃc
> Inspector", "priority": 2
>
> }

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User updated successfully", "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "phone":
> "+91-9876543210",
>
> "division": "Traﬃc", "designation": "Traﬃc Inspector", "priority": 2,
>
> "updatedAt": "2026-03-25T11:00:00.000Z" }
>
> }

**8.** **Activate** **User**

> POST /api/v1/users/:id/activate Authorization: Bearer \<accessToken\>
> Content-Type: application/json

**Permission:** SUPERADMIN only

**Description:** Activate a deactivated user.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User activated", "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000",
>
> "employeeId": "EMP001", "status": "ACTIVE",
>
> "updatedAt": "2026-03-25T11:05:00.000Z" }
>
> }

**9.** **Deactivate** **User**

> POST /api/v1/users/:id/deactivate Authorization: Bearer
> \<accessToken\> Content-Type: application/json

**Permission:** SUPERADMIN only

**Description:** Deactivate an active user.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User deactivated", "data": {
>
> "id": "550e8400-e29b-41d4-a716-446655440000", "employeeId": "EMP001",
>
> "status": "INACTIVE",
>
> "updatedAt": "2026-03-25T11:10:00.000Z" }
>
> }

**10.** **Delete** **User**

> DELETE /api/v1/users/:id Authorization: Bearer \<accessToken\>

**Permission:** SUPERADMIN only

**Description:** Permanently delete a user account.

**Success** **Response** **(200** **OK):**

> {
>
> "success": true,
>
> "message": "User deleted successfully" }

**Common** **Response** **Formats**

**Success** **Response** **Template**

> {
>
> "success": true,
>
> "message": "Operation successful", "data": {
>
> // Response-speciﬁc data }
>
> }

**Error** **Response** **Template**

> {
>
> "success": false,
>
> "message": "Error message", "errors": \[
>
> {
>
> "ﬁeld": "ﬁeldName",
>
> "message": "Validation error message" }
>
> \] }

**Paginated** **Response** **Template**

> {
>
> "success": true, "data": {
>
> "items": \[\], "pagination": {
>
> "page": 1, "limit": 10, "total": 50, "totalPages": 5
>
> } }
>
> }

**Error** **Handling**

**HTTP** **Status** **Codes**

||
||
||
||
||
||
||
||
||
||
||
||
||

**Common** **Error** **Codes**

> // Invalid Token {
>
> "success": false,
>
> "message": "No token provided or invalid token", "statusCode": 401
>
> }
>
> // Permission Denied {
>
> "success": false,
>
> "message": "You do not have permission to perform this action",
> "statusCode": 403
>
> }
>
> // Resource Not Found {
>
> "success": false,
>
> "message": "Shift not found", "statusCode": 404
>
> }
>
> // Validation Error {
>
> "success": false,
>
> "message": "Validation failed",
>
> "errors": \[ {
>
> "ﬁeld": "trainNumber",
>
> "message": "Train number is required" }
>
> \],
>
> "statusCode": 400 }
>
> // Rate Limit Exceeded {
>
> "success": false,
>
> "message": "Too many requests, please try again later", "statusCode":
> 429
>
> }

**Business** **Logic** **Errors**

> // Shift Already Completed {
>
> "success": false,
>
> "message": "Cannot update a completed shift", "statusCode": 422
>
> }
>
> // Invalid Time Range {
>
> "success": false,
>
> "message": "Sign-on time cannot be before train arrival time",
> "statusCode": 422
>
> }
>
> // Insuﬃcient Permissions {
>
> "success": false,
>
> "message": "Only SUPERADMIN can delete shifts", "statusCode": 403
>
> }

**Authentication** **Header** **Format**

All protected endpoints require the Authorization header:

> Authorization: Bearer \<access_token\>

**Example:**

> GET /api/v1/shifts HTTP/1.1 Host: api.railway.com
>
> Authorization: Bearer
> eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjU1MGU4NDAw...

**Notes**

> All timestamps are in ISO 8601 format (UTC)
>
> All IDs are UUIDs (v4)
>
> Rate limiting is applied to prevent abuse
>
> Token expiry: Access token valid for 1 hour, Refresh token for 7 days
>
> Pagination: Default page size is 10, max 100

**Last** **Updated:** March 25, 2026

**API** **Version:** v1

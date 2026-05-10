# Error Handling & API Integration Audit Report

Audit scope: Flutter project error handling, API integrations, snackbar/toast messaging, and auth/session handling.

## 1. Global Error Handling Components

### ApiClient (core)

- Endpoint/File Name: `lib\core\network\api_client.dart`
- What is currently implemented:
  - Unified error mapping for 400/401/403/404/429/5xx, SocketException, TimeoutException, FormatException, and fallback.
  - 401 redirects to login via `AppRouter.navigatorKey` and clears auth storage.
  - Context-aware 400/404 messages mapped for key endpoints.
- What is expected (based on rules):
  - Must be used for all API calls so mapping and 401 redirect is enforced consistently.
- Action required by developers:
  - Ensure all API calls use `ApiClient` (or reuse its error mapping) to align with specs.

### HTTP Interceptor (core)

- Endpoint/File Name: `lib\core\http_interceptor.dart`
- What is currently implemented:
  - Refresh-token flow on 401, retry request with new token.
  - SocketException mapped to 503 with message "No Internet Connection - Please check your network." (not spec exact).
  - Other errors return 504 "Network Timeout".
- What is expected:
  - SocketException should show "No internet connection. Check your network." (exact).
  - Timeout (>30s) should show "Request timed out. Please try again.".
  - 500–599 should show "Server error. Please try again later.".
  - 401 should trigger "Your session has expired. Please log in again." + navigate to login (unless refresh succeeds).
- Action required:
  - Align offline/timeout behavior and status codes with the spec; ensure user-visible messages are compliant.

### AppToast / AuthWidgets

- Endpoint/File Name: `lib\core\network\app_toast.dart`, `lib\Auth\auth_widgets.dart`
- What is currently implemented:
  - AppToast maps `AppException` to safe message; otherwise generic fallback.
  - AuthWidgets show raw message strings passed by callers.
- What is expected:
  - User-facing strings must match spec messages per status code/endpoint and must not show raw exception text or stack traces.
- Action required:
  - Ensure callers do not pass raw exception strings to UI; standardize with spec messages.

## 2. Endpoint-by-Endpoint Findings

### Auth Endpoints

#### Login

- Endpoint/File Name: `POST /Auth/Login` in `lib\Auth\api_service.dart` and UI in `lib\Auth\login_page.dart`
- What is currently implemented:
  - Shows "Login failed. Status code: X" or "Login error: $e".
  - No 401 redirect or spec-based 400/404 messages.
- What is expected:
  - 400 → "Incorrect email or password, or account not activated yet."
  - 404 → "Account not found. Check your university code."
  - 401 → "Your session has expired. Please log in again." + navigate login.
  - 429/5xx/timeout/socket/format/other exceptions → spec messages.
- Action required:
  - Replace hardcoded/raw messages with spec mapping; avoid raw exception output.

#### Activate Account

- Endpoint/File Name: `POST /Auth/activate` in `lib\Auth\api_service.dart` and `lib\Auth\activation_page.dart`
- What is currently implemented:
  - Maps 400 to "Invalid data", 404 to "Account not found", 409 to "Account already activated".
  - On exception: "Connection error: $e".
- What is expected:
  - 400 → "Invalid or expired activation link."
  - 404 → "Activation link is invalid or has expired."
  - 429 → "Too many activation attempts. Please wait."
  - 401 redirect with spec message.
- Action required:
  - Update error handling to spec messages; add 429 handling; prevent raw exception string exposure.

#### Refresh Token

- Endpoint/File Name: `POST /Auth/refresh-token` in `lib\core\http_interceptor.dart`
- What is currently implemented:
  - Token refresh on 401, returns success/failure with no user-facing messaging.
- What is expected:
  - On refresh failure, user should be redirected to login with "Your session has expired..." on next call.
- Action required:
  - Confirm redirect occurs when refresh fails and downstream endpoints get 401.

#### Verify Session

- Endpoint/File Name: `GET /Auth/verify-session` in `lib\Auth\main_file.dart`
- What is currently implemented:
  - If API fails, assumes token valid and allows offline.
  - No spec mapping for error messaging.
- What is expected:
  - 401 should redirect to login with spec message.
- Action required:
  - Ensure 401 results in logout/redirect (not handled by interceptor here because raw response used).

---

### Admin Endpoints

#### Create Doctor / TA

- Endpoint/File Name: `POST /Admin/create-doctor` and `POST /Admin/create-TA` in `lib\Home\creatDoctorOrTA.dart`
- What is currently implemented:
  - 400 throws "Bad request" or backend message.
  - 401 throws "Unauthorized - Token may be expired".
  - 409 "Email already exists".
  - Raw exception message shown via SnackBar.
  - Debug `print()` logs with token fragments and response body.
- What is expected:
  - 400 should be spec message when applicable (bulk create has explicit message; otherwise generic).
  - 401 should redirect and show session-expired message.
  - No raw exception or internal response body shown to user.
- Action required:
  - Replace raw error exposure and prints; align 401 handling and messages.

#### Create Course

- Endpoint/File Name: `POST /Admin/create-course` in `lib\Home\creatCourse.dart`
- What is currently implemented:
  - 400/401 -> Exception; shown as "Error: ..." to user.
  - Response body printed; errors shown raw.
- What is expected:
  - 400 should map to "Invalid request. Please check your input and try again." (or other spec if defined).
  - 401 redirect and message.
- Action required:
  - Align messages and avoid raw exception exposure.

#### Delete User (single)

- Endpoint/File Name: `DELETE /Admin/delete-user/{code}` in `lib\Home\DeleteUserPage.dart`, `lib\Home\DoctorsListPage.dart`, `lib\Home\TAsListPage.dart`
- What is currently implemented:
  - DeleteUserPage: 404 -> "User not found - Code may be incorrect"; 401 -> "Unauthorized"; 400 -> backend message; 500 -> custom message.
  - Doctors/TAs list: on errors, shows backend message or raw body; 500 special case.
- What is expected:
  - 404 → "User not found."
  - 401 → session-expired message + redirect.
  - 500–599 → "Server error. Please try again later."
- Action required:
  - Replace custom/raw messaging with spec mapping; ensure 401 navigation.

#### Delete Course (single)

- Endpoint/File Name: `DELETE /Admin/delete-course/{id}` in `lib\Home\DeleteCoursePage.dart`, `lib\Home\CoursesListPage.dart`
- What is currently implemented:
  - 404 -> "Course not found - ID may be incorrect".
  - 401 -> "Unauthorized".
  - Other errors: backend message or raw body.
- What is expected:
  - 404 → "Course not found."
  - 401 → session-expired message + redirect.
  - 5xx → spec message.
- Action required:
  - Standardize error handling and remove raw error exposure.

#### Bulk Delete Students

- Endpoint/File Name: `POST /Admin/bulk-delete-students` in `lib\Home\DeleteStudentsBulkPage.dart`
- What is currently implemented:
  - On non-200, shows "Failed (statusCode)" or backend message; on exceptions shows "Error: $e".
- What is expected:
  - 400/404/401/403/429/5xx -> spec messages.
- Action required:
  - Add spec-based mapping and remove raw exception display.

#### Reset Student Account

- Endpoint/File Name: `POST /Admin/reset-student-account` in `lib\Home\ResetStudentAccountPage.dart`
- What is currently implemented:
  - Non-200 -> backend message or "Failed to reset account"; exceptions shown raw.
- What is expected:
  - 404 → "Student account not found."
  - 401 → session-expired message + redirect.
- Action required:
  - Map 404/401 to spec and avoid raw error exposure.

#### Reset System For New Year

- Endpoint/File Name: `POST /Admin/reset-system-for-new-year` in `lib\Home\ResetStudentsForNewYearPage.dart`
- What is currently implemented:
  - Non-200 -> "Failed (statusCode)" or "Error: $e".
- What is expected:
  - 401 → session-expired message + redirect.
  - 5xx → spec message.
- Action required:
  - Standardize error handling; remove raw exception output.

#### Assign Staff

- Endpoint/File Name: `POST /Admin/assign-staff` in `lib\Home\AssignStaffPage.dart`
- What is currently implemented:
  - Non-200 -> "Error: ${response.body}".
  - Exception -> "Failed to connect: $e".
- What is expected:
  - 400 → "Staff member is already assigned or codes are invalid."
  - 401 → session-expired + redirect.
  - 404/5xx etc per spec.
- Action required:
  - Map status codes to spec and remove raw response exposure.

#### Admin Stats

- Endpoint/File Name: `GET /Admin/number-of-*` in `lib\Home\AdminDashboard.dart` via `ApiService.getAdminStatistic`
- What is currently implemented:
  - Handles 401 with auto-logout; other errors logged via print; no user-facing spec messages.
- What is expected:
  - 401 should navigate to login with session-expired message.
  - 5xx and other statuses should use spec messaging if shown to user.
- Action required:
  - Align messaging if surfaced; reduce raw print logs.

---

### Course Endpoints

#### My Courses / Student Courses

- Endpoint/File Name: `GET /Course/my-courses` and `GET /Course/student-courses` in `lib\Home\CoursesListPage.dart`, `lib\Home\DoctorDashboardPage.dart`
- What is currently implemented:
  - 401: CoursesListPage sets "Session expired..." only; DoctorDashboard auto-logout.
  - Other errors display raw response body or exception string.
- What is expected:
  - 401 → "Your session has expired. Please log in again." + navigate login.
  - 404 → "Course not found." (if applicable).
  - 5xx/timeout/socket/format -> spec messages.
- Action required:
  - Standardize error mapping and redirect on 401.

#### Enroll Student (Single)

- Endpoint/File Name: `POST /Course/enroll` in `lib\Home\CourseEnrollmentPage.dart`
- What is currently implemented:
  - Non-200 throws exception with backend message; UI shows "Error: $e".
- What is expected:
  - 400 → "Student is already enrolled in this course." (specific)
  - 401 redirect with spec message.
- Action required:
  - Map 400 and 401 to spec; avoid raw exception display.

#### Enroll Students (Bulk)

- Endpoint/File Name: `POST /Course/enroll-bulk` in `lib\Home\BulkCourseEnrollmentPage.dart`
- What is currently implemented:
  - Non-200 shows "Error: $e" with backend message if present.
- What is expected:
  - 400 → "Invalid request. Please check your input and try again." (no explicit bulk enroll spec).
  - 401 redirect with spec message.
- Action required:
  - Apply spec mapping and avoid raw errors.

#### Enrolled Students / Count Enrolled

- Endpoint/File Name: `GET /Course/get-enrolled-students/{courseId}` and `GET /Course/number-of-enrolled-students/{courseId}` in `lib\Home\Reports\EnrolledStudentsPage.dart`, `lib\Home\CoursesListPage.dart`, `lib\Home\DoctorDashboardPage.dart`
- What is currently implemented:
  - Errors set to raw "Error statusCode: body" or exception string.
- What is expected:
  - 404 → "Course not found."
  - 401 redirect with spec message.
- Action required:
  - Standardize error mapping and avoid raw response exposure.

---

### Attendance Endpoints

#### Submit Attendance (QR / PIN)

- Endpoint/File Name: `POST /Attendance/submit` in `lib\Home\QRScannerPage.dart`, `lib\Home\Reports\StudentSessionsHistoryPage.dart`
- What is currently implemented:
  - On error, shows `response.body` or `e.toString()` in dialogs/snackbars.
  - No mapping for 400/404/401.
- What is expected:
  - 400 → "Cannot submit attendance — session may be closed or already submitted."
  - 401 → session-expired message + navigate login.
  - 404 → "Session or student not found."
- Action required:
  - Map status codes to spec; remove raw body/exception exposure.

#### Manual Add Attendance

- Endpoint/File Name: `POST /Attendance/manual-add` in `lib\Home\Reports\SessionAttendeesPage.dart`
- What is currently implemented:
  - Error shows raw response body.
- What is expected:
  - 400 → "Student is already marked present."
  - 404 → "Session or student not found."
  - 401 → session-expired + redirect.
- Action required:
  - Apply spec mapping and avoid raw response exposure.

#### Delete Attendance

- Endpoint/File Name: `DELETE /Attendance/delete/{sessionId}/{studentId}` in `lib\Home\Reports\SessionAttendeesPage.dart`
- What is currently implemented:
  - Error shows raw response body or generic "Error connecting to server".
- What is expected:
  - 404 → "Session or student not found."
  - 401 → session-expired + redirect.
- Action required:
  - Apply spec mapping and avoid raw response exposure.

#### Session Attendees / Reports / Absence Warnings

- Endpoint/File Name:
  - `GET /Attendance/session-attendees/{sessionId}` in `lib\Home\Reports\SessionAttendeesPage.dart`
  - `GET /Attendance/lecture-report/{courseId}` in `lib\Home\Reports\LectureReportPage.dart`
  - `GET /Attendance/section-report/{courseId}` in `lib\Home\Reports\SectionReportPage.dart`
  - `GET /Attendance/absence-warnings/{courseId}` in `lib\Home\Reports\AbsenceWarningsPage.dart`
- What is currently implemented:
  - Errors shown as "Error {status}: body" or raw exception string.
- What is expected:
  - 404 → "Course not found." (course-related) or "Session not found." where applicable.
  - 401 → session-expired + redirect.
  - 403 → "You don't have permission to do this."
  - 5xx/timeout/socket/format -> spec messages.
- Action required:
  - Replace raw error exposure with spec mapping.

---

### Session Endpoints

#### Create Session

- Endpoint/File Name: `POST /Session/create` in `lib\Home\Reports\CreateSessionPage.dart`, `lib\features\session\session_service.dart`, `lib\features\session\create_session_screen.dart`
- What is currently implemented:
  - CreateSessionPage: on error shows raw response body or "Error: $e".
  - SessionService throws exceptions with raw response body.
  - CreateSessionScreen shows "Error: $e" in snackbar.
- What is expected:
  - 400 → "A conflicting session already exists for this course."
  - 401 → session-expired + redirect.
- Action required:
  - Apply spec mapping and avoid raw response exposure.

#### Stop Session / Resume Session

- Endpoint/File Name:
  - `PUT /Session/stop/{sessionId}` in `lib\Home\Reports\LiveDashboardPage.dart`, `lib\features\session\session_service.dart`, `lib\features\session\qr_display_screen.dart`, `lib\Home\Reports\CourseDashboardPage.dart`
  - `PUT /Session/resume/{sessionId}` in the same files
- What is currently implemented:
  - Raw response bodies in SnackBars; exceptions shown as "Error: $e".
  - LiveDashboard shows "Action failed: ${response.body}".
- What is expected:
  - 400 (stop) → "This session is already stopped."
  - 400 (resume) → "This session is already active."
  - 401 → session-expired + redirect.
- Action required:
  - Apply spec mapping and remove raw response/exception exposure.

#### Rotate QR / Update Radius / Live Dashboard SSE

- Endpoint/File Name:
  - `POST /Session/rotate-qr/{sessionId}` in `lib\Home\Reports\LiveDashboardPage.dart`
  - `PUT /Session/update-radius/{sessionId}` in `lib\Home\Reports\LiveDashboardPage.dart`
  - `GET /Session/live-dashboard/{sessionId}` (SSE) in `lib\Home\Reports\LiveDashboardPage.dart`
- What is currently implemented:
  - Some status handling (400 shows "Session already closed"), 403 shows custom "Unauthorized" message.
  - Other errors ignored or show raw body.
- What is expected:
  - 403 → "You don't have permission to do this."
  - 404 → "Session not found."
  - 401 → session-expired + redirect.
- Action required:
  - Standardize spec messaging; avoid raw body output.

---

## 3. Raw Exception / Stack Trace Exposure

- Endpoint/File Name: Multiple
- What is currently implemented:
  - Many SnackBars/Dialogs show `e.toString()` or `response.body` directly.
  - Debug `print()` calls log response bodies and tokens.
- What is expected:
  - No raw exceptions, stack traces, or backend raw bodies should be exposed to users.
- Action required:
  - Remove or hide raw exception/response text from user-facing UI; replace with spec messages.

## 4. Missing or Unused Central Handling

- Endpoint/File Name: `lib\core\network\api_client.dart`
- What is currently implemented:
  - `ApiClient` exists but is not used anywhere outside its file.
- What is expected:
  - Unified error handling should be applied to all API calls.
- Action required:
  - Integrate ApiClient (or copy its mapping logic) into all API flows to ensure consistent behavior.

## 5. Language & Localization

- Endpoint/File Name: Multiple
- What is currently implemented:
  - Messages are English, mixed custom, and raw backend messages.
- What is expected:
  - Messages must match the app's language and the exact strings specified.
- Action required:
  - Replace all mismatched messages with spec strings; ensure Arabic/English consistency.

---

## Summary of Critical Gaps

- Widespread raw error exposure in SnackBars/dialogs and direct response body display.
- Many endpoints not mapped to required 400/404 context-aware messages.
- Inconsistent 401 handling; some screens do not redirect to login.
- ApiClient’s standardized mapping is not used in most API calls.
- Offline/timeout handling in interceptor is non-compliant with spec messages.

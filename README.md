   # TRADERS — SARAVANAS (Employee Management Application)

A modern, robust, offline-first Android application designed and engineered for employee management, attendance tracking, and salary/advance ledger management for **Saravanas**.



## 1. Project Overview

- **Repository / Project Name:** `traders`
- **Application & Brand Name:** `Saravanas`
- **Primary Audience:** Company Owner / Administrator (Single-tenant, offline, high-reliability)
- **Tagline:** *People. Work. Management.*



## 2. Key Features

1. **Branded Visual Experience:**
   - Custom minimal, premium "S" monogram logo and animated SARAVANAS wordmark.
   - Elegant startup flow with seamless transition into the dashboard.
   - Clean, corporate Material Design 3 UI with deep navy (`#142B50`), teal (`#087E8B`), and crisp typography.

2. **Executive Home Dashboard (HCI-Optimized):**
   - **Leave Report (Hero Action):** Dedicated monthly calendar displaying daily Present, Absent, and Not Marked employees alongside date-specific prepaid salary advance transactions.
   - **Total Employees Card:** Displays live active employee count and navigates to the dedicated Employee Directory (no employee names cluttered on the home screen).
   - **Employee Report Card:** Generates real 4-sheet `.xlsx` Excel reports (Consolidated or Individual Employee) with one-tap download and sharing.
   - **Salary / Salary Advance Card:** Direct prepaid salary advance recording with searchable employee selector, real-time remaining balance preview, and overpayment protection.
   - **Employees Entry Button:** Opens the full searchable Employee Directory.

3. **Employee Directory:**
   - Auto-generated sequential, non-reusable employee codes (`EMP0001`, `EMP0002`, ...).
   - Real-time search by employee name, code, or designation.
   - Full employee profile management: designation, phone number, joining date, and salary.
   - Soft deactivation preserving historical financial and attendance integrity.

3. **Attendance Management:**
   - Monthly attendance calendar with visual indicators (Present: Green, Absent: Red, Unmarked: Default).
   - Monthly summary cards (Total Present, Total Absent, Unmarked days).
   - Strict database-level unique constraint (`UNIQUE(employee_id, attendance_date)`) preventing duplicates.
   - Complete employee data isolation — marking one employee never affects another.

4. **Salary & Advance Ledger:**
   - Exact integer paise arithmetic — zero floating-point rounding errors.
   - Prepaid salary advances with date, amount, salary period, and optional reason.
   - Dynamic real-time calculation: `Remaining Salary = Monthly Salary - Total Advances for Period`.
   - Clear Indian currency formatting (`₹20,000`).
   - Advance transactions displayed directly on the attendance calendar with separate indicators (teal dot).

5. **Data Safety & Integrity:**
   - ACID-compliant SQLite transactions with foreign key enforcement.
   - Database migrations and schema versioning.
   - Local JSON-based backup and restore with checksum and schema validation.
   - Absolute protection against data leakage between employees and periods.



## 3. Technology Stack

- **Framework:** Flutter (Channel stable, Material Design 3)
- **Language:** Dart
- **State Management:** Riverpod (`flutter_riverpod`)
- **Navigation:** `go_router`
- **Database:** SQLite (`sqflite`, `path_provider`, `path`)
- **Calendar:** `table_calendar`
- **Formatting & Utilities:** `intl`, `uuid`



## 4. Architecture: Clean Architecture & Repository Abstraction

The project is structured according to Clean Architecture principles to ensure that the SQLite data layer can be seamlessly swapped with a remote MySQL/Node.js API in the future without modifying any UI or domain logic.


lib/
├── core/
│   ├── constants/       # App constants, routes, asset paths, keys
│   ├── errors/          # Failure and exception classes
│   ├── theme/           # Color palettes, typography, theme data
│   └── utils/           # Currency formatters, date formatters, validators
├── data/
│   ├── datasources/     # SQLite database helper, tables, queries, migrations
│   ├── models/          # Data transfer models with SQLite mapping
│   └── repositories/    # Concrete SQLite implementations of domain repositories
├── domain/
│   ├── entities/        # Pure business entities (Employee, Attendance, Advance, Salary)
│   └── repositories/    # Abstract repository contracts (Interfaces)
└── presentation/
    ├── providers/       # Riverpod state notifiers and providers
    ├── screens/
    │   ├── splash/      # Animated Saravanas splash screen
    │   ├── home/        # Dashboard with live statistics and directory
    │   ├── employee/    # Add employee, employee profile, settings
    │   ├── attendance/  # Interactive attendance calendar & daily dialog
    │   ├── salary/      # Financial cards, advance list, record advance dialog
    │   └── admin/       # Administrator profile, backup & restore, about
    └── widgets/         # Common UI components (cards, buttons, inputs, dialogs)


### Future MySQL Migration Path

All entities use UUID primary keys. SQLite repositories implement abstract interfaces (e.g. `EmployeeRepository`, `AttendanceRepository`, `SalaryRepository`). To migrate:
1. Implement `ApiEmployeeRepository` implementing `EmployeeRepository`.
2. Connect to the Node.js/MySQL REST API.
3. Switch the Riverpod repository providers from SQLite to API implementations.
Zero UI or business rule changes are required.

---

## 5. Setup & Physical Android Device Debugging

### Prerequisites
- Java JDK 17
- Android SDK & Platform Tools (ADB)
- Flutter SDK (`N:\flutter` or configured in system `PATH`)

### Connecting a Physical Android Device

1. **Enable Developer Options on your phone:**
   - Open **Settings** > **About Phone**.
   - Tap **Build Number** 7 times until you see *"You are now a developer!"*.
2. **Enable USB Debugging:**
   - Go to **Settings** > **System / Additional Settings** > **Developer Options**.
   - Turn on **USB Debugging**.
3. **Connect to Computer:**
   - Connect your phone using a good quality USB data cable.
   - On your phone screen, look for the prompt *"Allow USB debugging?"*, check *"Always allow from this computer"*, and tap **Allow**.
4. **Verify ADB Detection:**
   ```bash
   adb devices -l
   ```
   You should see your device listed (e.g. `device` status, not `unauthorized`).
5. **Run the Application:**
   ```bash
   flutter devices
   flutter run -d <your-device-id>
   ```

### Building Release APK
```bash
flutter build apk --release
```
The output APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 6. Database Schema Summary

- `employees`: `id` (UUID PK), `employee_code` (Unique), `name`, `phone`, `designation`, `joining_date`, `is_active`, timestamps.
- `attendance`: `id` (UUID PK), `employee_id` (FK), `attendance_date` (ISO `YYYY-MM-DD`), `status` (`present` / `absent`), `UNIQUE(employee_id, attendance_date)`.
- `salary_records`: `id` (UUID PK), `employee_id` (FK), `monthly_salary_paise` (INTEGER), `effective_from`, timestamps.
- `advances`: `id` (UUID PK), `employee_id` (FK), `amount_paise` (INTEGER), `transaction_date`, `salary_period` (`YYYY-MM`), `description`, timestamps.
- `app_settings`: `id`, `setting_key` (Unique), `setting_value`, `updated_at`.

---

## 7. Versioning & Git Workflow

- Remote: `https://github.com/PrajitPranav/Traders.git`
- Local commits are made per development phase.
- Pushes are performed manually by the repository owner.


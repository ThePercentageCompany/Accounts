# The Percentage Company (TPC) — Business Accounts & Management System

> **Enterprise Invoicing, Quotations, Operational Accounting, Shareholders Equity, HR & Payroll System** built with **Flutter** (Web & Mobile) and inspired by the modern **Zoho Books** and **Apple iOS** design language.

---

## 🌟 Executive Summary

**TPC Accounts** is an all-in-one business management and financial ERP workspace designed for **The Percentage Company FZ LLC**. It eliminates the need for expensive proprietary subscriptions and database infrastructure by directly interfacing with **Google Workspace (Google Sheets, Google Drive, Google OAuth 2.0)** while providing a local-first offline cache with automatic background synchronization.

---

## 🚀 Key Modules & Capabilities

```
├── 📊 Dashboard & KPIs          (Real-time cash flow, P&L, monthly income vs. expense chart)
├── 🧾 Invoices & Receipts       (Zoho-styled split invoice creator, live PDF preview, payments)
├── 📑 Quotations & Estimates    (Formal client estimates, A4 PDF generation, status workflow)
├── 💳 Income & Expenses         (Operational day-to-day accounts, supplier bills, receipts)
├── 👥 Customers Directory       (Client accounts, TRN tax records, balances, contact info)
├── 🧑‍💼 Employees & HR           (Staff profiles, salary structure, visa/passport expiry)
├── ⏱️ Attendance & Overtime     (Daily clocking, leaves, half-days, automated OT hours)
├── 💰 Payroll & Payslips        (Automated salary calculations, payslip PDF generation)
├── 📈 Financial Reports         (Monthly P&L, bank/cash movement, tax audit reports)
└── ⚙️ Company & Shareholders    (Branding, bank setup, shareholder equity %, capital ledger)
```

---

### 1. 📊 Executive Dashboard
- **6 KPI Metric Cards**: Total Income, Total Expenses, Net Profit, Cash & Bank Liquidity, Outstanding Receivables, and Payable Supplier Bills.
- **Interactive Dual Bar Chart**: Monthly Income vs. Expense visual comparison.
- **Profit & Loss Summary**: Gross revenue, operational expenditure, and net margin calculation.
- **Recent Transactions & Live Feed**: Quick transaction monitoring with category icons and status badges.

---

### 2. 🧾 Invoices & Client Billing
- **Zoho-Style Split-Pane Editor**: Real-time form on the left, live pixel-perfect A4 PDF preview on the right.
- **Automated Calculations**: Line items, quantity, rate, customizable discount, and UAE 5% VAT.
- **Official TPC Numbering**: Automatic generation of consecutive sequential invoice codes (e.g., `TPC-2026-000001`).
- **Payment Lifecycle**: Record full or partial payments across Bank and Cash accounts, with automatic receipt generation.
- **Document Actions**: Direct PDF printing, downloading, and 1-click archiving to private Google Drive.

---

### 3. 📑 Quotations & Estimates
- **Formal Price Quotations**: Create and issue client proposals with custom scope, unit rates, and validity dates.
- **Unified Brand Design**: Matching typography, header layout, bank details, and signature fields.
- **Status Pipeline**: Manage proposals through `Draft`, `Sent`, `Accepted`, `Invoiced`, or `Declined`.

---

### 4. 💳 Operational Income & Expenses (Accounts)
- **Segmented Transaction Modal**: Instant logging between **Income** (Consulting, Retainers, Digital Services) and **Expenses** (Rent, Utilities, Software SaaS, Marketing, Hardware, Travel).
- **Supplier Bill Tracking**: Differentiate between immediate payments and unpaid supplier invoices with due date tracking.
- **Account Routing**: Real-time cash movement split between **Bank Account** and **Cash in Hand**.
- **Attachment Storage**: Upload and attach receipts/invoices directly to transaction records.

---

### 5. ⚙️ Company Settings & Shareholders / Capital Equity
- **Company Profile**: Business name, TRN tax number, phone, email, and address.
- **Banking Configuration**: Bank name, account number, IBAN, and account holder name.
- **Shareholders & Equity Ledger**:
  - Track partners, investors, and founders.
  - Ownership percentage (%) allocation progress bar.
  - Total invested capital amount (AED) per partner.
  - Record capital contributions with automated cash flow ledger credits.

---

### 6. 🧑‍💼 Human Resources, Attendance & Payroll
- **Employee Directory**: Manage staff information, designations, basic pay, allowances, and visa documentation.
- **Daily Attendance System**: Mark Present, Absent, Half Day, Paid Leave, Unpaid Leave, and Sick Leave with check-in/out times.
- **Automated Payroll Engine**:
  - Calculates base salary according to configurable divisor (30 days) and scheduled days.
  - Automatic deductions for unapproved absences and proportional half-days.
  - Overtime arithmetic based on recorded hourly rates, plus bonuses and deductions.
  - Approval workflow with locked historical snapshots and formal Payslip PDF generation.

---

## 🛠️ Architecture & Technology Stack

| Layer | Technology |
| :--- | :--- |
| **Framework** | [Flutter 3.29+ / Dart 3.8+](https://flutter.dev) (Single codebase for Web, Android, iOS, Desktop) |
| **State Management** | `flutter_bloc` / `Cubit` for predictable, testable reactive state flows |
| **Data Immutability** | `freezed` and `json_serializable` for type-safe models |
| **UI Design System** | Custom **Zoho Books** & **Apple iOS** design language (Curved squircles, HSL color tokens, rich typography) |
| **Local Cache & Sync**| Local-first `SharedPreferences` cache with background async synchronization (`SyncManager`) |
| **Cloud Storage & DB**| **Google Sheets API** (Structured database tabs) + **Google Drive API** (PDF/attachment vault) |
| **Authentication** | **Google OAuth 2.0 / Google Sign-In** with secure token refresh |
| **PDF Engine** | `pdf` & `printing` packages with high-resolution vector A4 rendering |

---

## 📁 Repository Structure

```
tpc_invoice/
├── lib/
│   ├── core/
│   │   ├── auth/           # Google OAuth, session management, onboarding
│   │   ├── sync/           # Local-first caching & background sync engine
│   │   ├── theme/          # Zoho design tokens, color palettes, card decorations
│   │   └── widgets/        # Brand logo, responsive shell, stat cards, badges
│   ├── features/
│   │   ├── billing/        # Invoices, customers, company profile, dashboard
│   │   │   ├── domain/     # Models, calculations, totals, repository contracts
│   │   │   ├── data/       # Google Sheets repository, PDF generation
│   │   │   └── presentation/# Dashboard, invoice editor, customer lists
│   │   ├── quotations/     # Client quotes and proposals
│   │   └── office/         # HR, attendance, payroll, income & expenses
│   │       ├── domain/     # Payroll & accounting calculation rules
│   │       ├── data/       # Direct Google workspace office repository
│   │       └── presentation/# Unified office, payroll & financial screens
│   └── main.dart           # Application entrypoint & navigation router
├── backend/
│   └── apps-script/        # Google Apps Script code for Sheets schema
├── config/                 # Google OAuth client configurations (web/android/ios)
├── test/                   # 31+ unit and widget test suites
└── web/                    # Web entry point, manifest, favicons, logos
```

---

## 💻 Getting Started Locally

### 1. Prerequisites
- **Flutter SDK**: `>= 3.24.0` (Dart `>= 3.8.0`)
- **Google Chrome** (for web development) or an Android/iOS emulator

### 2. Installation
```bash
# Clone the repository
git clone https://github.com/ThePercentageCompany/Accounts.git
cd Accounts

# Install Flutter dependencies
flutter pub get

# Run code generation if needed
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Launching in Demo Mode (Local Preview)
```bash
flutter run -d chrome
```
*In demo mode, all changes are saved locally to the browser's storage without requiring Google authentication.*

### 4. Connecting to Live Google Workspace
1. Copy `config/google.example.json` to `config/google.web.json`.
2. Provide your Google Cloud OAuth `clientId`.
3. Link your Google Spreadsheet and Google Drive Folder during the initial onboarding step.
4. For detailed configuration instructions, refer to [`SETUP.md`](file:///d:/THE-PERCENTAGE-SOURCE-CODES/tpc_invoice/SETUP.md).

---

## 🧪 Testing & Code Quality

The project includes an automated test suite covering state management, accounting arithmetic, payroll logic, and responsive widget layout:

```bash
# Run static analysis (0 warnings, 0 errors)
flutter analyze

# Execute all 31 unit and widget tests
flutter test
```

---

## 🚀 Deployment

The web application is configured for deployment on **Vercel** or any static/cloud hosting platform:
- Build command: `bash vercel-build.sh`
- Output directory: `build/web`
- Production routing: Configured via `vercel.json` with SPA HTML5 fallback.

---

## 📄 License & Proprietary Rights

© 2026 **The Percentage Company FZ LLC**. All rights reserved.  
*Internal business software developed exclusively for company accounting, payroll, and invoicing operations.*

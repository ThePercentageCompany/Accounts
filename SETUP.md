# TPC Business - Live Multi-Tenant Google Setup

TPC Business connects directly to **Google Sign-In + Google Sheets API (v4) + Google Drive API (v3)**.

### ✨ Multi-Tenant Live Features:
1. **Any user can sign in with their own Google account**.
2. **Automatic Provisioning**: If a user signs in for the first time, an onboarding wizard prompts for company name, invoice prefix, TRN, and bank details.
3. **Private Cloud Database & Storage**: The app automatically creates a private Google Spreadsheet (`TPC Business - <CompanyName>`) with all 10 schema tabs and a private Google Drive folder (`TPC Business Documents - <CompanyName>`) in the user's own Google Drive.
4. **Master View Access**: View-only access (`role: reader`) is automatically granted to the master admin email (`thepercentagecompany1@gmail.com`) so executive oversight is preserved.
5. **No Apps Script Maintenance Required**: Direct REST API integration with OAuth tokens means zero backend scripts or allowlists are required to support new users.

---

## 1. Quick Start / Running Locally

### Demo / Local Mode (Zero Setup)
```bash
flutter run -d chrome
```

### Connected Google Mode
```bash
flutter run -d chrome --web-port=7357 --dart-define-from-file=config/google.web.json
```

---

## 2. Google Cloud Platform (GCP) Configuration

1. Create a Google Cloud Project at [Google Cloud Console](https://console.cloud.google.com/).
2. Enable the following APIs:
   - **Google Sheets API**
   - **Google Drive API**
3. Configure the **OAuth Consent Screen**:
   - User Type: **External** (or Internal for Google Workspace)
   - Add scopes:
     - `https://www.googleapis.com/auth/spreadsheets`
     - `https://www.googleapis.com/auth/drive`
     - `https://www.googleapis.com/auth/userinfo.email`
   - Add test users (if in Testing mode).
4. Create **OAuth Client IDs**:
   - **Web**: Authorised JavaScript origins & redirect URIs:
     - `https://accounts.thepercentagecompany.com`
     - `http://localhost:7357` (for local development)
   - **Android**: Package name and SHA-1 fingerprint.
   - **iOS**: Bundle ID and reversed client ID URL scheme.

---

## 3. Configuration File (`config/google.web.json`)

```json
{
  "CONNECTED": "true",
  "GOOGLE_CLIENT_ID": "110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com",
  "GOOGLE_SERVER_CLIENT_ID": "",
  "MASTER_ADMIN_EMAIL": "thepercentagecompany1@gmail.com"
}
```

---

## 4. Automatic Database Tabs Provisioned in Google Sheets

When a user onboards, their private Google Spreadsheet is created with 10 structured tabs:

| Tab Name | Purpose |
|---|---|
| `Customers` | Client directory & contact info |
| `Invoices` | Full invoice data & line items |
| `Settings` | Company identity, bank details, UAE TRN, terms |
| `Employees` | Staff directory, salary, allowances, employment dates |
| `Attendance` | Daily attendance, overtime, absence tracking |
| `Payroll` | Monthly payroll drafts, calculations, approvals & payslips |
| `Finance` | Direct income/expenses, supplier bills & ledger |
| `Quotations` | Quotation & proposal management |
| `Invoice Register` | Tabular overview of all issued invoices & PDF links |
| `Payment Register` | Tabular overview of all recorded payment receipts |

---

## 5. Building for Production

### Web
```bash
flutter build web --release --dart-define-from-file=config/google.web.json
```

### Android APK / App Bundle
```bash
flutter build apk --release --dart-define-from-file=config/google.android.json
flutter build appbundle --release --dart-define-from-file=config/google.android.json
```

### iOS (on macOS)
```bash
flutter build ipa --release --dart-define-from-file=config/google.ios.json
```

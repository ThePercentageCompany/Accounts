# TPC Accounts — Capital Amount in Company Finance

## Purpose

This document defines the complete standard, double-entry accounting formulas, and display rules for calculating shareholder capital, equity, loans, and business finance in TPC Accounts.

**Core Fundamental Accounting Rule: Capital is NOT Income.**

Shareholder capital increases company **Equity** and normally increases an **Asset** (Bank, Cash, or Fixed Asset). It does **NOT** increase Revenue, Operating Income, or Profit.

---

## 1. Financial Structure & Classification

TPC Accounts strictly maintains five separate accounting categories according to standard double-entry accounting principles (IFRS):

```text
1. ASSETS (Debit Normal Balance)
   - Cash in Hand
   - Bank Accounts
   - Accounts Receivable (A/R from Customer Invoices)
   - Fixed Assets (Computers, Equipment, Vehicles)
   - Less: Accumulated Depreciation (Contra-Asset)

2. LIABILITIES (Credit Normal Balance)
   - Accounts Payable (A/P from Supplier Bills)
   - Accrued Payroll Payable
   - Bank Loans / Overdrafts
   - Shareholder Loans Payable (Monies lent by owners to company)

3. EQUITY (Credit Normal Balance)
   - Shareholder Paid-in Capital (Cash, Bank, Asset contributions)
   - Less: Formal Capital Withdrawals (Reductions of capital)
   - Retained Earnings (Prior years' accumulated profits/losses)
   - Current Year Net Profit / Loss
   - Other Equity Adjustments

4. INCOME / REVENUE (Credit Normal Balance)
   - Service & Consulting Revenue (Invoices)
   - Sales Income
   - Other Operating Income

5. EXPENSES (Debit Normal Balance)
   - Salaries & Staff Allowances (Payroll)
   - Office Rent & Utilities
   - Software & Cloud Infrastructure
   - Marketing & Advertising
   - Travel & General Office Expenses
   - Depreciation Expense
```

### The Fundamental Balance Sheet Equation

$$\text{Total Assets} = \text{Total Liabilities} + \text{Total Equity}$$

Expanded:
$$\text{Total Assets} = \text{Total Liabilities} + (\text{Net Shareholder Capital} + \text{Retained Earnings} + \text{Current Net Profit/Loss} + \text{Equity Adjustments})$$

---

## 2. Capital Metrics & Values to Display

The Capital & Equity dashboard and reports display the following standard metrics:

```text
1. Agreed Capital          : Total committed capital by memorandum / contract
2. Gross Capital Invested  : Total cash, bank, and asset contributions made
3. Capital Withdrawals     : Formal returns/withdrawals of contributed capital
4. Net Capital Invested    : Gross Contributions minus Capital Withdrawals
5. Outstanding Capital     : Agreed Capital minus Net Capital Invested
6. Cash & Bank Capital     : Liquid contributions deposited into company accounts
7. Asset Capital           : Physical assets contributed (laptops, vehicles, etc.)
8. Shareholder Loans       : Debt owed by company to shareholders (Liability)
9. Current Equity          : Net Capital + Retained Earnings + Current Profit/Loss
```

### Harmonized Example Dataset

```text
Agreed Capital                  AED 100,000
Gross Capital Contributions     AED  80,000
  ├── Cash / Bank Capital       AED  65,000
  └── Asset Capital             AED  15,000
Capital Withdrawals             AED   2,000
-------------------------------------------
Net Capital Invested            AED  78,000
Outstanding Capital             AED  22,000

Retained Earnings               AED   5,000
Current Year Net Profit         AED  12,000
-------------------------------------------
Current Equity                  AED  95,000

Shareholder Loans (Liability)   AED   5,000
```

---

## 3. Agreed Capital Calculation

Agreed Capital is the nominal capital shareholders have committed to invest in accordance with the company trade license or shareholder agreement.

### Formula

$$\text{Agreed Capital} = \sum (\text{Shareholder Agreed Capital})$$

### Example

```text
Partner A (60% ownership) : AED  60,000
Partner B (40% ownership) : AED  40,000
---------------------------------------
Total Agreed Capital      : AED 100,000 (100%)
```

---

## 4. Gross Capital Contributions

Gross Capital Invested is the cumulative sum of all actual equity contributions introduced by shareholders.

### Formula

$$\text{Gross Capital Contributions} = \text{Cash} + \text{Bank Transfers} + \text{Asset Contributions} + \text{Additional Capital}$$

### Example (Partner A)

```text
Initial Cash Contribution       : AED 30,000
Asset Contribution (Hardware)   : AED  6,000
Additional Cash Contribution    : AED  4,000
--------------------------------------------
Total Gross Contributions       : AED 40,000
```

---

## 5. Capital Withdrawals

A formal reduction or withdrawal of capital is a return of equity to shareholders.

$$\text{Net Capital Invested} = \text{Gross Capital Contributions} - \text{Capital Withdrawals}$$

### Example (Partner A)

```text
Gross Contributions             : AED 40,000
Formal Capital Withdrawal       : AED  2,000
--------------------------------------------
Net Capital Invested            : AED 38,000
```

> [!IMPORTANT]
> A Capital Withdrawal is **NOT** an operating expense. It debits Equity (reducing Shareholder Capital) and credits an Asset account (reducing Bank/Cash). It does not affect Net Profit or P&L.

---

## 6. Outstanding Capital Calculation

Outstanding Capital represents the committed capital that has not yet been paid in by shareholders.

### Formula

$$\text{Outstanding Capital} = \max(0, \text{Agreed Capital} - \text{Net Capital Invested})$$

### Example

```text
Company Agreed Capital          : AED 100,000
Total Net Capital Invested      : AED  78,000
---------------------------------------------
Outstanding Capital             : AED  22,000
```

If contributions exceed agreed capital, outstanding capital is displayed as **AED 0.00**, and the excess is reported as **Additional Paid-in Capital / Surplus Equity**.

---

## 7. Individual Shareholder Ledgers

Each shareholder maintains an independent capital account in the double-entry general ledger.

### Comprehensive Example:

#### Partner A (60% Shareholding)
```text
Agreed Capital                  : AED 60,000
Cash / Bank Contributions       : AED 34,000  (AED 30,000 initial + AED 4,000 additional)
Asset Contributions             : AED  6,000  (Office Computer Equipment)
Total Gross Contributions       : AED 40,000
Capital Withdrawals             : AED (2,000)
--------------------------------------------
Net Capital Invested            : AED 38,000
Outstanding Capital             : AED 22,000  (AED 60,000 - AED 38,000)
Contribution %                  : 63.33%      (38,000 / 60,000 × 100)
```

#### Partner B (40% Shareholding)
```text
Agreed Capital                  : AED 40,000
Cash / Bank Contributions       : AED 31,000
Asset Contributions             : AED  9,000  (Office Furniture & Fixtures)
Total Gross Contributions       : AED 40,000
Capital Withdrawals             : AED      0
--------------------------------------------
Net Capital Invested            : AED 40,000
Outstanding Capital             : AED      0  (AED 40,000 - AED 40,000)
Contribution %                  : 100.00%     (40,000 / 40,000 × 100)
```

---

## 8. Capital Contribution Percentage

Measures what percentage of agreed capital each partner (and the company overall) has fulfilled.

### Formula

$$\text{Contribution \%} = \left( \frac{\text{Net Capital Invested}}{\text{Agreed Capital}} \right) \times 100$$

### Verified Calculations

- **Partner A**: $(38,000 / 60,000) \times 100 = \mathbf{63.33\%}$
- **Partner B**: $(40,000 / 40,000) \times 100 = \mathbf{100.00\%}$
- **Total Company**: $(78,000 / 100,000) \times 100 = \mathbf{78.00\%}$

---

## 9. Journal Entries for Cash Capital

When a partner deposits capital into the company bank account:

### Example: Partner A deposits AED 20,000

```text
DEBIT:  Bank Account (Asset)                           AED 20,000
CREDIT: Shareholder Capital — Partner A (Equity)       AED 20,000
```

### Financial Effect:
- Assets (Bank): **+AED 20,000**
- Equity (Shareholder Capital): **+AED 20,000**
- Income / Revenue: **AED 0.00**
- Profit & Loss: **AED 0.00 (Unchanged)**

---

## 10. Journal Entries for Asset Capital

When a partner contributes non-monetary assets (e.g. equipment, laptops, vehicles) as capital:

### Example: Partner A contributes computer equipment worth AED 6,000

```text
DEBIT:  Fixed Assets — Computer Equipment (Asset)      AED 6,000
CREDIT: Shareholder Capital — Partner A (Equity)       AED 6,000
```

### Financial Effect:
- Assets (Fixed Assets): **+AED 6,000**
- Equity (Shareholder Capital): **+AED 6,000**
- Bank / Cash: **AED 0.00**
- Income / Profit: **AED 0.00 (Unchanged)**
- Asset Register: Asset is added at historical cost AED 6,000 and depreciates over useful life.

---

## 11. Distinction: Capital vs. Cash

Capital and Cash must never be conflated:
- **Cash & Bank** = Liquid asset available to spend.
- **Capital** = Source of funds representing owners' equity stake.

### Example:
1. Shareholders invest **AED 50,000** cash into Bank.
   - Bank = AED 50,000 | Shareholder Capital = AED 50,000.
2. Company buys office laptop for **AED 10,000** from Bank.
   - Bank = AED 40,000
   - Fixed Assets (Laptop) = AED 10,000
   - **Total Assets = AED 50,000**
   - **Shareholder Capital = AED 50,000**

Liquidity was transformed from cash to equipment; capital remains unchanged.

---

## 12. Distinction: Capital vs. Profit & Loss

Capital introduced is **NOT revenue**, and capital withdrawn is **NOT an expense**.

### Example:
```text
Shareholder Capital Introduced  : AED 50,000
Customer Invoice Revenue        : AED 20,000
Operating Expenses Paid         : AED  8,000
--------------------------------------------
Net Profit (Income - Expenses)  : AED 12,000  (20,000 - 8,000)

Total Company Equity:
  Shareholder Capital           : AED 50,000
  Current Net Profit            : AED 12,000
  ------------------------------------------
  Total Equity                  : AED 62,000
```

---

## 13. Current Total Equity Calculation

$$\text{Current Equity} = \text{Net Shareholder Capital} + \text{Retained Earnings} + \text{Current Net Profit/Loss} + \text{Equity Adjustments}$$

### Harmonized Calculation:
```text
Net Shareholder Capital         AED 78,000
Retained Earnings (Prior Years) AED  5,000
Current Year Net Profit         AED 12,000
Other Equity Adjustments        AED      0
------------------------------------------
Current Total Equity            AED 95,000
```

---

## 14. Distinction: Shareholder Capital vs. Shareholder Loans

A Shareholder Loan is money borrowed by the company from an owner that must be repaid. It is a **Liability**, not equity.

### Example: Partner A lends the company AED 20,000

```text
DEBIT:  Bank Account (Asset)                           AED 20,000
CREDIT: Shareholder Loan Payable — Partner A (Liability) AED 20,000
```

### Financial Effect:
- Cash & Bank (Asset): **+AED 20,000**
- Liabilities (Loans Payable): **+AED 20,000**
- Shareholder Capital (Equity): **AED 0.00**
- Income / Profit: **AED 0.00**

When the company repays the loan:
```text
DEBIT:  Shareholder Loan Payable (Liability)           AED 20,000
CREDIT: Bank Account (Asset)                           AED 20,000
```

---

## 15. Finance Dashboard Integration

The Finance Dashboard presents business performance and financial position in distinct, uncluttered sections:

```text
══════════════════════════════════════════════════════════════
 BUSINESS PERFORMANCE (Profit & Loss for the Period)
══════════════════════════════════════════════════════════════
 Total Revenue / Income               AED 35,000
 Total Operating Expenses             AED 16,500
 -------------------------------------------------------------
 Net Operating Profit                 AED 18,500

══════════════════════════════════════════════════════════════
 FINANCIAL POSITION & BALANCE SHEET SUMMARY
══════════════════════════════════════════════════════════════
 Cash in Hand                         AED  7,500
 Bank Accounts                        AED 51,000
 Accounts Receivable (A/R)            AED 12,000
 Fixed Assets (Net Book Value)        AED 18,000
 -------------------------------------------------------------
 Total Assets                         AED 88,500

 Accounts Payable (A/P)               AED  5,000
 Shareholder Loans (Liability)        AED  2,500
 -------------------------------------------------------------
 Total Liabilities                    AED  7,500

 Total Shareholder Capital            AED 75,000
 Retained Earnings                    AED  1,000
 Current Period Net Profit            AED  5,000
 -------------------------------------------------------------
 Total Equity                         AED 81,000
 Total Liabilities + Equity           AED 88,500 (Balanced: AED 0.00)

══════════════════════════════════════════════════════════════
 CAPITAL & EQUITY POSITION
══════════════════════════════════════════════════════════════
 Agreed Capital                       AED 100,000
 Gross Contributions                  AED  80,000
   ├── Cash / Bank Contributions      AED  65,000
   └── Asset Contributions            AED  15,000
 Capital Withdrawals                  AED   2,000
 -------------------------------------------------------------
 Net Capital Invested                 AED  78,000
 Outstanding Capital                  AED  22,000
 Capital Contribution %               78.00%
 Current Total Equity                 AED  95,000
```

---

## 16. Capital & Equity Screen UI Breakdown

The Capital & Equity screen displays six top-level KPI cards and a clear contribution breakdown:

### KPI Metric Cards:
```text
[ Agreed Capital ]        [ Net Capital Invested ]     [ Outstanding Capital ]
   AED 100,000                 AED 78,000                    AED 22,000

[ Asset Contributions ]   [ Shareholder Loans ]        [ Current Equity ]
   AED 15,000                  AED 5,000                     AED 95,000
```

### Capital Contributions Breakdown:
```text
Cash / Bank Contributions       AED  65,000
Asset Contributions             AED  15,000
-------------------------------------------
Gross Capital Contributions     AED  80,000
Less: Capital Withdrawals       AED  (2,000)
-------------------------------------------
Net Capital Invested            AED  78,000
```

---

## 17. Master Shareholder Summary Table

| Shareholder | Ownership % | Agreed Capital | Cash / Bank | Asset Capital | Withdrawals | Net Invested | Outstanding | Contribution % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **Partner A** | 60.00% | AED 60,000 | AED 34,000 | AED 6,000 | AED 2,000 | AED 38,000 | AED 22,000 | 63.33% |
| **Partner B** | 40.00% | AED 40,000 | AED 31,000 | AED 9,000 | AED 0 | AED 40,000 | AED 0 | 100.00% |
| **Total** | **100.00%** | **AED 100,000** | **AED 65,000** | **AED 15,000** | **AED 2,000** | **AED 78,000** | **AED 22,000** | **78.00%** |

### Row Calculations Verification:
1. **Partner A**:
   - $\text{Net Invested} = 34,000 + 6,000 - 2,000 = \mathbf{38,000}$
   - $\text{Outstanding} = 60,000 - 38,000 = \mathbf{22,000}$
   - $\text{Contribution \%} = (38,000 / 60,000) \times 100 = \mathbf{63.33\%}$
2. **Partner B**:
   - $\text{Net Invested} = 31,000 + 9,000 - 0 = \mathbf{40,000}$
   - $\text{Outstanding} = 40,000 - 40,000 = \mathbf{0}$
   - $\text{Contribution \%} = (40,000 / 40,000) \times 100 = \mathbf{100.00\%}$
3. **Total Column Sums**:
   - $\text{Agreed} = 60,000 + 40,000 = \mathbf{100,000}$
   - $\text{Cash} = 34,000 + 31,000 = \mathbf{65,000}$
   - $\text{Assets} = 6,000 + 9,000 = \mathbf{15,000}$
   - $\text{Withdrawals} = 2,000 + 0 = \mathbf{2,000}$
   - $\text{Total Net Invested} = 65,000 + 15,000 - 2,000 = \mathbf{78,000}$
   - $\text{Total Outstanding} = 100,000 - 78,000 = \mathbf{22,000}$
   - $\text{Overall Contribution \%} = (78,000 / 100,000) \times 100 = \mathbf{78.00\%}$

---

## 18. Capital Movement Statement / Report

The Capital & Equity Movement Report tracks the flow of equity over any selected reporting period.

### Formula

$$\text{Closing Capital} = \text{Opening Capital} + \text{New Cash Contributions} + \text{Asset Contributions} - \text{Capital Withdrawals} \pm \text{Equity Adjustments}$$

### Example Statement:
```text
Opening Capital (01 Jan 2026)         AED 50,000
  + New Cash Contributions            AED 20,000
  + New Asset Contributions           AED  6,000
  - Capital Withdrawals               AED (3,000)
  ± Equity Adjustments                AED      0
------------------------------------------------
Closing Capital (31 Dec 2026)         AED 73,000
```

---

## 19. Chart of Accounts: General Ledger Structure

Every shareholder has a dedicated sub-ledger account within the 3000 (Equity) group:

```text
3000  EQUITY
  ├── 3010  Share Capital — Partner A
  ├── 3020  Share Capital — Partner B
  ├── 3100  Capital Withdrawals — Partner A (Contra-Equity)
  ├── 3110  Capital Withdrawals — Partner B (Contra-Equity)
  ├── 3200  Retained Earnings (Prior Years)
  └── 3300  Current Year Profit / Loss
```

---

## 20. Sources of Financial Calculations

All financial summary values must be aggregated directly from **POSTED double-entry journal lines**:

| Metric | Source Calculation |
|---|---|
| **Total Revenue** | $\sum \text{POSTED Income Account Credits} - \sum \text{POSTED Income Account Debits}$ |
| **Total Expenses** | $\sum \text{POSTED Expense Account Debits} - \sum \text{POSTED Expense Account Credits}$ |
| **Net Profit** | $\text{Total Revenue} - \text{Total Expenses}$ |
| **Cash & Bank Balance** | $\sum \text{Cash/Bank Debits} - \sum \text{Cash/Bank Credits}$ |
| **Accounts Receivable** | $\sum \text{Customer Invoice Balances Due}$ |
| **Accounts Payable** | $\sum \text{Unpaid Supplier Bills}$ |
| **Fixed Assets (Net)** | $\text{Original Asset Cost} - \text{Accumulated Depreciation}$ |
| **Net Shareholder Capital** | $\sum \text{Capital Account Credits} - \sum \text{Capital Account Debits}$ |
| **Current Total Equity** | $\text{Net Capital} + \text{Retained Earnings} + \text{Current Net Profit} + \text{Equity Adjustments}$ |

---

## 21. Balance Sheet Example & Zero-Variance Check

```text
══════════════════════════════════════════════════════════════
 BALANCE SHEET AS AT 31 DECEMBER 2026
══════════════════════════════════════════════════════════════
 ASSETS
   Current Assets:
     Cash in Hand                           AED  7,500
     Bank Accounts                          AED 51,000
     Accounts Receivable (A/R)              AED 12,000
   -----------------------------------------------------------
   Total Current Assets                     AED 70,500

   Non-Current (Fixed) Assets:
     Computer Equipment & Hardware          AED 20,000
     Less: Accumulated Depreciation         AED (2,000)
   -----------------------------------------------------------
   Net Fixed Assets                         AED 18,000
 ═════════════════════════════════════════════════════════════
 TOTAL ASSETS                               AED 88,500
 ═════════════════════════════════════════════════════════════

 LIABILITIES
   Current Liabilities:
     Accounts Payable (Supplier Bills)      AED  5,000
     Shareholder Loans Payable              AED  2,500
 -------------------------------------------------------------
 TOTAL LIABILITIES                          AED  7,500

 EQUITY
   Partner A Paid-in Capital                AED 60,000
   Partner B Paid-in Capital                AED 15,000
   Retained Earnings (Prior Years)          AED  1,000
   Current Year Net Profit                  AED  5,000
 -------------------------------------------------------------
 TOTAL EQUITY                               AED 81,000
 ═════════════════════════════════════════════════════════════
 TOTAL LIABILITIES + TOTAL EQUITY           AED 88,500
 ═════════════════════════════════════════════════════════════
```

### Mathematical Proof of Balance:
$$\text{Variance} = \text{Total Assets} - (\text{Total Liabilities} + \text{Total Equity})$$
$$\text{Variance} = \text{AED } 88,500 - (\text{AED } 7,500 + \text{AED } 81,000) = \mathbf{\text{AED } 0.00}$$

---

## 22. Capital Transaction Data Model

Every capital transaction record contains the following mandatory fields:

```json
{
  "id": "CTX_1726000000000",
  "date": "2026-09-12",
  "shareholderId": "sh_01",
  "shareholderName": "Partner A",
  "transactionType": "capitalContribution",
  "contributionType": "bank",
  "amountCents": 2000000,
  "assetName": "",
  "destinationAccount": "Bank Account",
  "status": "posted",
  "reference": "BANK-DEP-2026-001",
  "notes": "Tranche 2 equity contribution via Emirates NBD transfer"
}
```

### Supported Transaction Types:
- `capitalContribution` (Initial or milestone capital injection)
- `additionalCapital` (Supplementary equity contribution)
- `assetContribution` (Contribution of laptops, equipment, vehicles)
- `capitalWithdrawal` (Formal return of capital)
- `equityAdjustment` (Revaluation or opening balance adjustment)

---

## 23. Key Accounting Rules Summary

1. **Capital is not Revenue/Income**: Capital contributions never touch Income or Profit & Loss.
2. **Capital Withdrawals are not Expenses**: Withdrawals debit Equity and credit Bank/Cash.
3. **Shareholder Loans are Liabilities**: Shareholder loans are payable obligations, not equity.
4. **Asset Contributions increase Fixed Assets & Equity**: Contributed assets are entered in the Asset Register at fair value and depreciate systematically.
5. **Purchasing Fixed Assets does not immediately reduce Profit**: It converts cash/bank to a fixed asset; the cost is recognized as an expense gradually over time via Depreciation.
6. **Depreciation is an Expense**: Debits Depreciation Expense (reducing Profit) and credits Accumulated Depreciation (reducing Asset Book Value).
7. **Every Journal Entry Must Balance**: Total debits must equal total credits with 0 variance.
8. **Individual Shareholder Sub-ledgers**: Track each partner's agreed capital, actual paid-in amount, withdrawals, and outstanding balance.
9. **Separate Nominal from Actual**: Agreed Capital vs. Net Paid-in Capital are maintained independently.
10. **Balance Sheet Equilibrium**: The balance sheet must satisfy $\text{Assets} = \text{Liabilities} + \text{Equity}$ at all times.

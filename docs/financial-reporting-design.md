# Financial reporting workspace — implementation specification

## Implemented status (October 2026)

The application now implements permission-checked report configuration and a company account registry; reviewed statement classifications; previous-period, previous-year and custom comparisons; complete trial-balance opening/movement/closing columns; real monthly dashboard and P&L trends; exact minor-unit reconciliation; account activity and source-record drill-down; ledger account/type/search filters, columns and pagination; saved views with access-checked share links; and PDF, XLSX, CSV and web print from one frozen filtered snapshot. Tables preserve financial columns on mobile and hold headers/subtotals above a bounded row viewport. New company profiles default to AED, and existing accounting currency restrictions are retained.

Deploy the updated backend with the Flutter client to enable the new endpoints. Reporting configuration is versioned in the existing control registry; no existing spreadsheet headers or posted records are rewritten. Owners can save shared configuration and views; employees with company-wide Reports access can read them. Source records retain their separate record permissions. Classify existing ledger identities in Reports > Chart of Accounts; incomplete classifications remain explicit and gross/operating profit stays unavailable.

Current-year earnings are unclosed earnings within the configured financial year, including any posted transfers; prior-year unclosed earnings are the remainder. Both reconcile with accumulated earnings and posted equity without double counting. Amount precision remains the existing two-decimal ledger contract. Branch/department/project/cost-center reporting and budget-versus-actual are not offered because current journal records contain neither dimensions nor budget data. PDF/Excel downloads and print use the existing web platform path; native download behavior remains the existing platform limitation. The remainder of this document records the original target design and accounting rationale.

## Original scope and implementation plan

The existing Flutter workspace supplies navigation, light/dark appearance, permission checks and cache subscriptions. Preserve those integrations. This change adds a shared report title, searchable accounts, zero-balance filters, density and negative-number preferences, formatted financial tables, explicit reconciliation differences, and posted ledger detail. Mobile retains financial columns through horizontal scrolling. CSV account contents follow search and zero filters; report-wide totals are labeled separately.

The attached request ends at section 9 without further text. No sample financial records are introduced. Existing currencies and posting rules remain authoritative. The specifications below cover the full requested destination; items called out as dependencies are not implemented controls.

## Review findings

The old report UI mixed raw numeric strings with prose summaries, omitted hierarchy and gave mobile users different information from desktop. Ledger details were long list tiles with weak separation between debit, credit and running balance. Dashboard period labels were vague. Account search and density controls were absent. The current backend has only five account groups, not the classifications needed for full statements; inferred categories would misrepresent accounts.

## Design system and layout

Use existing Inter font and Material color scheme with the workspace primary color as the sole accent. Background uses surfaceContainerLowest, cards surface, table headings surfaceContainerHighest; text uses onSurface and onSurfaceVariant. Reconciliation combines icons and labels. Avoid red/green as the sole indicator. Financial values use tabular numerals, two decimals and right alignment; missing data is an em dash, never zero. Default new workspaces to AED; changing presentation currency must not convert or relabel posted balances without a supported exchange-rate policy.

Desktop: retain workspace sidebar; report content fills remaining width, max reading width 1440. Header has company, breadcrumbs, title and period. Below it, a wrapping toolbar contains date preset, comparison, filters, refresh, saved views and export. Summary cards precede a grouped table; optional charts sit beside it above 1200px. At tablet widths toolbar wraps and charts stack. On mobile use the workspace drawer, stack summary cards and scroll financial tables horizontally. Sticky headers belong in a bounded vertically scrolling table; do not nest unconstrained vertical scroll containers. Comfortable rows target 52px; dense rows 36px. Interactive targets remain at least 48px. At large text scales let labels wrap and retain table scrolling.

## Navigation and shared interactions

Destination order: Dashboard, Chart of Accounts, Journal Entries, General Ledger, Trial Balance, Profit & Loss, Balance Sheet, Report Settings. Chart of Accounts requires a first-class account registry; do not substitute historical journal-line names. Journal Entries uses the existing Journals flow. Report Settings holds financial-year start, date pattern, grouping separators, precision, negative format and default density. Persist preferences per workspace/user. Workspace permissions govern every destination and export.

Report context must show company name from verified profile, currency from ledger configuration, accrual basis (posted journals), inclusive dates, active dimensions, last successful fetch timestamp and cached/offline status. Balance Sheet uses As of; activity reports use From/To. Presets: this month, last month, quarter to date, financial year to date and custom. Financial-year presets must use configured year start. Comparisons are disabled until supported, not rendered with invented values. Reset restores default period, clears dimensions/search and shows zero accounts according to preference. A no-results state keeps filters visible; an empty ledger offers Journal Entries only when permitted. Permission failures offer no bypass. Integrity errors clear invalid cached totals. Refresh errors label saved data explicitly.

Saved views store settings only: version, workspace, report kind, dates or relative preset, comparison, dimensions, columns, density and hide-zero flag. Shareable URLs reference permission-checked view IDs; never embed account balances. Restore scroll and expanded account IDs after drill-down. Export PDF, XLSX, CSV and print through one immutable report snapshot containing applied filters and timestamp; record export scope. The current implementation supplies CSV only. Add remaining formats with server-side permission checks and the same rows and totals as the on-screen snapshot.

## Balance Sheet

Group account registry mappings as Assets → Current (cash, bank, receivables, inventory, prepayments, other) and Non-current (fixed assets, accumulated depreciation, other); Liabilities → Current (payables, accruals, tax, short-term debt) and Non-current (long-term debt, other); Equity → capital, retained earnings, current-year earnings, drawings/distributions. Contra accounts stay in their assigned category. Show group subtotals, total assets, total liabilities, total equity and liabilities + equity.

Compute and display difference in integer minor units: assets − liabilities − equity. Zero means Balanced; otherwise Needs review with exact signed difference. Backend currently rejects non-reconciling statements with LEDGER_INTEGRITY. Keep that protection. Accumulated earnings currently includes all unclosed income/expense balances; do not relabel it current-year earnings. To split retained and current-year earnings, introduce validated closing-entry metadata and financial-year boundaries. Transfers already posted to equity must be excluded from derived earnings. Comparative columns use separate cutoff dates and identical account mappings. Negative normal balances get an explanatory tooltip without reclassification.

## General Ledger

Account picker includes registry code, name and group; optional all-account mode. Summary shows opening, period debit, period credit and closing. Table columns: date, journal/voucher, reference, description, counterparty, debit, credit, running balance; optional dimensions and document. The present API supplies date, number, description, sourceType, journalId and monetary columns; do not populate absent fields.

Opening = sum of debit − credit before From. Closing = opening + period debit − period credit. Display debit-positive convention and optionally Dr/Cr. Compute running balances before pagination/search using stable date, journal identity and line order. Alternative sorting may hide running balance or label it original-order balance; never recalculate after sorting. Mark reversal/adjustment only from explicit source metadata. A journal-number interaction currently opens available metadata; a full journal/source route must permission-check the source record and preserve the report state.

## Profit & Loss

Registry reporting roles determine Revenue, returns/discounts, net revenue, COGS, gross profit, operating expense categories, operating profit, other income/expense, finance costs, tax and net profit. Current API exposes aggregate Income and Expense only, so the implemented view retains those labels. No gross profit is inferred.

Net revenue = revenue − returns − discounts; gross profit = net revenue − COGS; operating profit = gross profit − operating expenses; net profit = operating profit + other income − other expense − finance costs − tax. Margins divide the relevant profit by net revenue × 100. Zero denominator displays Not defined. Monthly/quarterly columns require period aggregation from posted transactions, not splitting an annual balance evenly. Budgets appear only when approved budget data exists. Income/profit increases are favorable; expense increases unfavorable; label this interpretation alongside the variance.

## Trial Balance

Full view: code/name, opening debit/credit, period debit/credit, closing debit/credit. Simplified view: net closing debit/credit (current endpoint). Full view requires a From parameter on the trial balance route and separately aggregated opening and movement data. Use signed opening + debit movements − credit movements = signed closing; split each net opening/closing into its appropriate debit or credit column. Sum all six columns with exact minor-unit arithmetic. Show debit−credit differences for opening, movements and closing independently. Equality proves arithmetic balance only, not completeness or correct classification. Filtered subtotals and complete-ledger reconciliation must be separately labeled.

## Data contracts and implementation sequence

1. Introduce Account registry: id, code, name, group, reportingRole, normalSide, parentId, active; migrations preserve existing account IDs and require reviewed classifications. Add configured company currency/basis/year start and verified company display name to report metadata.
2. Standardize report request: kind, from/asOf, comparison, dimensions, zero policy; response: metadata, typed rows, group totals, overall totals, reconciliation, source references. Amounts stay decimal strings from integer minor-unit calculations. Dimensions filter both opening and movements consistently. Reject unauthorized dimensions before aggregation.
3. Add comparative snapshots. Variance = current − comparator; percentage = variance / abs(comparator) × 100. Comparator zero and current zero: 0%; comparator zero and nonzero current: Not defined. Custom comparisons explicitly label dates. Missing values remain unavailable.
4. Add full trial-balance movement endpoint, role-based statement groups and comparative exports. Preserve existing routes for compatibility.
5. Add saved-view persistence, permitted source routes, immutable PDF/XLSX/print snapshots, bounded sticky tables, pagination and column preferences.
6. Dashboard trends aggregate real monthly posted income and expense; prior-period cards compare equal-length periods with labeled dates. Gross profit requires COGS mapping. Cash/bank are point-in-time balances; profit is period activity. Do not render total-comparison bars as historical trends.

## Acceptance checks

Verify empty ledger, zero revenue, negative balances, missing metadata, ledger integrity failure, offline cache and forbidden employee access. Test closing transfers without double-counted earnings; inclusive date boundaries; leap years and non-January financial years; stable running balances across pages; filtered export parity; zero comparator behavior; keyboard focus, screen-reader table labels, dark contrast, 320px width and 200% text. All reconciliation and aggregation tests use minor-unit arithmetic. UI must preserve actual classifications and never invent unavailable balances.

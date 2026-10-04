# Mobile workspace design

The active SaaS workspace uses permission-aware Home, Invoices and Customers shortcuts, with other assigned modules grouped in More. Desktop navigation retains its sidebar from 900 logical pixels. The visited section stack and existing cache subscriptions retain loaded data, search, filters and scroll positions.

`mobile_components.dart` provides adaptive forms, searchable record selection, status chips, record summaries, mobile record actions and live line estimates. Forms use the existing validation and submission callbacks. Mobile forms keep actions outside the scrolling body and accommodate the keyboard; desktop forms retain dialogs. Record action sheets close before running the existing action, including its confirmations and permission checks.

Invoice, quotation, cash, receipt, payroll, asset, capital and company profile editors use the shared form surface. Customer and employee administration also use it. Date fields open calendars; desktop retains typed dates. Long mobile selections search already loaded options. Short choices and desktop selectors retain dropdowns. Invoice and quotation lines show a visual estimate; the server still computes and validates all saved totals.

Records show important dates, amounts, status and contact details before expanded fields. Status filters and searches operate on the existing returned dataset and do not trigger new API requests. Reports retain desktop tables and use account cards below 600 pixels, with date presets, a custom date/range picker and CSV export. Dashboard cards adapt to available width and text size. Shared buttons have a minimum 48-pixel target.

No new task module, attendance write workflow, personal allocations, product catalog or pagination API was introduced. Existing accounting restrictions and admin-granted employee access remain enforced. Authorization is still required; saved data does not grant offline access.

Validation includes the complete Flutter regression suite, additional phone widths 320/360/390/430, landscape, tablet and desktop, 150% text scaling, keyboard-inset forms, searchable sheets and cache-preserving navigation. Widget layout checks do not replace physical-device or live authenticated browser testing.

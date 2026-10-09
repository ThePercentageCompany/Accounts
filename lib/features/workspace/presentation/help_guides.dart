class HelpGuide {
  const HelpGuide(
      {required this.category,
      required this.title,
      required this.purpose,
      required this.useCase,
      required this.steps});
  final String category, title, purpose, useCase;
  final List<String> steps;
}

const helpGuides = <HelpGuide>[
  HelpGuide(
      category: "Getting started",
      title: "Create a workspace",
      purpose: "Set up a separate company workspace and its Google storage.",
      useCase: "Starting a company or managing another business separately.",
      steps: [
        "Sign in with Google and create a company using its name.",
        "Connect Google when prompted and wait for setup to finish.",
        "Open the workspace and complete the company profile in Settings."
      ]),
  HelpGuide(
      category: "Getting started",
      title: "Employee access",
      purpose:
          "Join the company with permissions assigned by its administrator.",
      useCase: "An employee needs to work without using the owner account.",
      steps: [
        "Ask your administrator for the invitation and private login code.",
        "Choose Employee login from the landing page and follow the invitation flow.",
        "Open the available sections; ask the administrator if a required action is missing."
      ]),
  HelpGuide(
      category: "Work & team",
      title: "Tasks",
      purpose:
          "Assign and follow work through To do, In progress, In review and Completed.",
      useCase: "Delegate a report, customer follow-up or internal deadline.",
      steps: [
        "Open Tasks and choose New Task if you have permission.",
        "Enter a title, assignee, dates, priority and optional project, tags and reminder. Save.",
        "Open the task to review details, add a comment or update its status. Use filters to find assigned or overdue work."
      ]),
  HelpGuide(
      category: "Work & team",
      title: "Calendar",
      purpose:
          "View task deadlines in a schedule; this uses the same tasks as the task board.",
      useCase: "Plan the week and check deadlines on a specific day.",
      steps: [
        "Open Calendar and select the date or available calendar view.",
        "Select a day to view its agenda, then open a task.",
        "Change task dates through its editor; the calendar reflects the saved task. Deadlines use Dubai time."
      ]),
  HelpGuide(
      category: "Work & team",
      title: "Projects",
      purpose: "Group tasks under a named project.",
      useCase: "Keep work for a client engagement or site together.",
      steps: [
        "Open Projects, add a project name, description and Active status.",
        "Select the project when creating or editing a task, then filter Tasks by project.",
        "Archive a project when appropriate. Reassign linked tasks before renaming or deleting a referenced project."
      ]),
  HelpGuide(
      category: "Work & team",
      title: "Employees",
      purpose: "Maintain employee records and control access through roles.",
      useCase: "Onboard a staff member or update employment information.",
      steps: [
        "Open Employees and add the employee details and employment status.",
        "Assign a role with the required sections and permitted actions.",
        "Use the access workflow to issue an invitation or revoke access. Share private login codes only with the intended employee."
      ]),
  HelpGuide(
      category: "Work & team",
      title: "Office & Attendance",
      purpose: "Keep attendance and overtime records linked to employees.",
      useCase: "Record daily presence and approved extra hours.",
      steps: [
        "Choose Attendance or Overtime in Office & Attendance.",
        "Review the employee, date, status or hours, and overtime rate and approval details.",
        "Use these records alongside payroll; only actions available to your role can be changed."
      ]),
  HelpGuide(
      category: "Work & team",
      title: "Notifications",
      purpose: "Read in-app task assignments and deadline reminders.",
      useCase: "Check new work or a task that needs attention.",
      steps: [
        "Select the notification bell or the Notifications entry in Settings.",
        "Open an alert to go to its task.",
        "Mark alerts read or unread, or mark all read. Alerts refresh while you use the app; device push permission is not required."
      ]),
  HelpGuide(
      category: "Sales & payments",
      title: "Customers",
      purpose:
          "Store the customers referenced by sales documents and payments.",
      useCase:
          "Create one reliable contact record before quoting or invoicing.",
      steps: [
        "Open Customers and add a name, contact information, address and tax number when applicable.",
        "Choose this customer in the invoice or quotation editor.",
        "Search Customers to update details. Referenced records may need their linked records resolved before deletion."
      ]),
  HelpGuide(
      category: "Sales & payments",
      title: "Quotations",
      purpose: "Prepare an offer before a sale becomes an issued invoice.",
      useCase: "Send a proposed scope and price for customer review.",
      steps: [
        "Open Quotations and create a draft with a customer, dates, items, prices and applicable tax.",
        "Review the draft and use the available send and document actions.",
        "Convert an eligible quotation to an invoice, then review and issue that invoice. The quotation itself does not post a sale."
      ]),
  HelpGuide(
      category: "Sales & payments",
      title: "Invoices",
      purpose: "Record sales, item details, tax and amounts due.",
      useCase: "Bill a customer and track the unpaid balance.",
      steps: [
        "Open Invoices and add an invoice draft. Select the customer, dates and line items.",
        "Check quantities, prices, discounts and tax, then save and review the draft.",
        "Issue the invoice when correct. Issuing creates the accounting entry; a draft does not. Use document actions for the invoice PDF."
      ]),
  HelpGuide(
      category: "Sales & payments",
      title: "Receipts & allocations",
      purpose: "Record money received and apply it to customer invoices.",
      useCase: "A customer pays one or more outstanding invoices.",
      steps: [
        "Open Receipts within Invoices or the available payment action on an eligible invoice.",
        "Enter payment date, amount, Cash or Bank account and reference. Select the appropriate invoice allocations.",
        "Confirm the payment and check the remaining invoice balance. Do not add the same payment again while confirmation is pending."
      ]),
  HelpGuide(
      category: "Sales & payments",
      title: "Credit notes & returns",
      purpose:
          "Correct returned items on an issued invoice while preserving accounting history.",
      useCase: "A customer returns part of a billed sale.",
      steps: [
        "Open the issued invoice and choose the available Return items action.",
        "Select eligible items and quantities, with the required date and reason.",
        "Review the resulting credit note and revised balance. Use an eligible void or reversal action for other corrections."
      ]),
  HelpGuide(
      category: "Sales & payments",
      title: "Documents & attachments",
      purpose:
          "Attach files and create supported document PDFs linked to their records.",
      useCase:
          "Keep an invoice PDF, expense evidence or task attachment with the related record.",
      steps: [
        "Open the record and its documents or attachments action.",
        "Choose a supported file within the displayed size limit, or create a PDF where available.",
        "Wait for confirmation and open the saved attachment. A queued upload is retried in the background."
      ]),
  HelpGuide(
      category: "Accounting",
      title: "Income & Expenses",
      purpose:
          "Record other income or business spending with its category and payment details.",
      useCase:
          "Record operating costs or income outside the invoiced sales workflow.",
      steps: [
        "Choose Income or Expenses and create a record with date, description, amount and applicable tax.",
        "Review the account and payment status before posting. Draft entries do not affect reports.",
        "Use the available payment or reversal action for a posted record. Avoid entering an invoiced sale again as separate income."
      ]),
  HelpGuide(
      category: "Accounting",
      title: "Payroll",
      purpose: "Prepare employee pay, review it and record payment.",
      useCase: "Run payroll for a month and retain employee pay details.",
      steps: [
        "Open Payroll and create a draft for the month and employee.",
        "Review salary, allowances, overtime, bonus and deductions using the available preview.",
        "Approve eligible payroll, then record its payment date, account and reference. Use payslip actions where available."
      ]),
  HelpGuide(
      category: "Accounting",
      title: "Fixed Assets",
      purpose:
          "Track equipment and other long-term assets, their depreciation and disposal.",
      useCase:
          "Purchase equipment and recognize its cost over its useful life.",
      steps: [
        "Add an asset draft with acquisition details, cost, useful life, residual value and payment account.",
        "Review and capitalize the asset using the available action.",
        "Use the depreciation workflow for an eligible period. Record disposal with its date, proceeds and reason when retiring the asset."
      ]),
  HelpGuide(
      category: "Accounting",
      title: "Capital & Equity",
      purpose:
          "Track shareholders, contributions, ownership information and shareholder loans.",
      useCase: "Record owner funding separately from trading income.",
      steps: [
        "Add shareholders and review their capital and ownership details.",
        "Create an appropriate capital contribution draft, choose the destination account and post when correct.",
        "Use Shareholder Loans for loan funding and the available posting or repayment workflow. A loan is different from an equity contribution."
      ]),
  HelpGuide(
      category: "Accounting",
      title: "Financial periods",
      purpose:
          "Define reporting periods and control whether dated postings are allowed.",
      useCase: "Close a reviewed period and prevent further postings in it.",
      steps: [
        "Open Financial periods within Balance Sheet.",
        "Review the period name, start and end dates, and status.",
        "Keep transaction dates in an open eligible period; resolve closed-period errors before posting."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Dashboard",
      purpose:
          "View a current task snapshot alongside financial performance and balances.",
      useCase: "Check priorities and review company performance at a glance.",
      steps: [
        "Open Home or Reports > Dashboard.",
        "Review task status counts, due-today and overdue counts; select an open task for details.",
        "Choose the reporting dates for financial cards and trends. Task counts show current work, independently of the financial reporting period."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Chart of Accounts",
      purpose: "Review account definitions used to group financial activity.",
      useCase: "Understand which account a transaction affects.",
      steps: [
        "Open Reports > Chart of Accounts.",
        "Review account names, codes and groups using the available settings.",
        "Check account classifications before interpreting financial reports; use permitted configuration actions when a change is needed."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Journal Entries",
      purpose:
          "Inspect complete posted accounting events and their debit and credit lines.",
      useCase: "Trace the accounting effect of a transaction.",
      steps: [
        "Open Journal Entries and find the entry by date or source.",
        "Inspect its Journal lines and compare total debits with total credits.",
        "Correct the source record through its eligible reversal, void or return workflow rather than duplicating a posting."
      ]),
  HelpGuide(
      category: "Reports",
      title: "General ledger",
      purpose: "Review posted movements and balances by account.",
      useCase: "Reconcile Bank or investigate a balance.",
      steps: [
        "Open General ledger and choose an account and date range.",
        "Use search and source filters to narrow the transactions.",
        "Open available drill-down details and compare the records with your supporting documents."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Trial balance",
      purpose: "List ledger balances and compare total debits and credits.",
      useCase: "Check the books before preparing financial reports.",
      steps: [
        "Open Trial balance and select the reporting date or period.",
        "Review account balances and debit and credit totals.",
        "Investigate unexpected accounts through the ledger. Balanced totals do not guarantee every account classification is correct."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Profit and loss",
      purpose: "Summarize income, expenses and profit for a period.",
      useCase: "Compare monthly performance or review spending.",
      steps: [
        "Open Profit and loss and select the date range.",
        "Review income, expense and profit totals and any available comparisons.",
        "Drill into supporting accounts where available. Draft transactions are excluded from posted financial activity."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Balance sheet",
      purpose: "Show assets, liabilities and equity at a selected date.",
      useCase: "Review what the company owns and owes.",
      steps: [
        "Open Balance sheet and choose the as-of date.",
        "Review cash, bank, receivables, assets, liabilities and equity.",
        "Investigate balances through supporting reports. The accounting relationship is Assets = Liabilities + Equity."
      ]),
  HelpGuide(
      category: "Reports",
      title: "Report Settings",
      purpose:
          "Control available report presentation preferences and saved settings.",
      useCase: "Keep report formatting consistent for reviewing or sharing.",
      steps: [
        "Open Reports > Report Settings.",
        "Review available date, number and presentation settings.",
        "Save preferences and check a report. Use the report export or print action where available."
      ]),
  HelpGuide(
      category: "Settings & data",
      title: "Settings & company profile",
      purpose:
          "Maintain company details and available appearance or document settings.",
      useCase: "Update business contact details and document branding.",
      steps: [
        "Open Settings > Company profile and review name, address, email, tax details and document prefixes.",
        "Save permitted changes; some accounting settings are locked after posting.",
        "Use System settings for available appearance and invoice or quotation document-design options. Preview a design using a saved record."
      ]),
  HelpGuide(
      category: "Settings & data",
      title: "Background sync & offline work",
      purpose:
          "Save supported edits on the device and confirm them online in the background.",
      useCase: "Continue routine work when a connection is interrupted.",
      steps: [
        "Use supported local record editing normally; previously loaded records can remain available offline.",
        "Reconnect and let background sync confirm the queued edits. Online posting and some document actions still require connectivity.",
        "If an edit is rejected or sign-in or device storage needs attention, follow the recovery action. Do not resubmit an uncertain payment as a new transaction."
      ]),
  HelpGuide(
      category: "Settings & data",
      title: "Permissions & troubleshooting",
      purpose:
          "Understand missing actions and recover from form or access errors.",
      useCase: "A section is missing or a record cannot be saved.",
      steps: [
        "Check required fields, dates and numbers using the displayed validation message.",
        "Ask the company administrator to confirm your role and permissions if a section or action is missing.",
        "For persistent errors, contact support with the section, steps and error text. Never send passwords, private login codes or sensitive documents."
      ]),
];

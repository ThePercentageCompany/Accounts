const helpAnswers = <({String topic, String title, String body})>[
  (
    topic: 'Getting started',
    title: 'What is TPC Accounts?',
    body:
        'TPC Accounts is a company workspace for customers, quotations, invoices, receipts, accounting reports and team tasks. Owners manage the workspace and employee access. Posted accounting activity feeds the financial reports.'
  ),
  (
    topic: 'Getting started',
    title: 'How do I create my first workspace?',
    body:
        'Sign in with Google, enter your company name and create a workspace. Connect Google when prompted to prepare the company storage. The setup screen shows progress and updates automatically while setup runs. When setup is complete, open the workspace and review your company settings.'
  ),
  (
    topic: 'Getting started',
    title: 'How do employees join?',
    body:
        'Your company administrator creates employee access and shares an invitation and a private login code. Use Employee login to join. The administrator controls which sections you can see and edit.'
  ),
  (
    topic: 'Getting started',
    title: 'Where should I start?',
    body:
        'Open Settings and check the company profile, currency and document details. Add a customer, then create your first invoice draft. Review it before issuing. Some sections and actions depend on your access permissions.'
  ),
  (
    topic: 'Getting started',
    title: 'What data belongs in each section?',
    body:
        'Customers stores the people or businesses you sell to. Invoices stores sales and item details. Quotations stores proposed prices. Income & Expenses records other money received or spent. Payroll stores employee pay details. Fixed Assets tracks long-term items such as equipment. Capital & Equity records shareholder funding. Tasks and Calendar organize work.'
  ),
  (
    topic: 'Sales & payments',
    title: 'How does a quotation connect to an invoice?',
    body:
        'A quotation is an offer, not proof of payment. The quotation workflow can convert an eligible quotation into an invoice. Review the resulting invoice before issuing it; a quotation alone does not mean the customer owes a posted invoice balance.'
  ),
  (
    topic: 'Sales & payments',
    title: 'Is an invoice the same as a receipt?',
    body:
        'No. An invoice records a sale and the amount due. A receipt records money received. An allocation connects that money to an invoice. A customer can have several invoices, and a receipt can be allocated across invoices through the payment workflow.'
  ),
  (
    topic: 'Sales & payments',
    title: 'What do Cash and Bank mean?',
    body:
        'These select the ledger account that receives or pays the money. Choose Cash for cash on hand and Bank for money moving through the business bank account. They are accounting accounts, not a list of card brands or payment services.'
  ),
  (
    topic: 'Sales & payments',
    title: 'How do I correct a posted transaction?',
    body:
        'Drafts can be edited where allowed. Issued or posted records have stricter rules because they affect accounting. Use the available return, credit note, void or reversal workflow rather than recording a second payment to undo the first. Required dates, reasons and eligibility depend on the transaction.'
  ),
  (
    topic: 'Accounting basics',
    title: 'What is a journal entry? What is a journal line?',
    body:
        'A journal entry is one complete accounting event, with a date, reference and balanced totals. Journal lines are its individual account movements. Example: an owner contributes 1,000 to the bank. One line debits Bank by 1,000; another credits Capital by 1,000. Total debits equal total credits. Debit and credit mean the two sides of an entry; they do not always mean money in and money out.'
  ),
  (
    topic: 'Accounting basics',
    title: 'What is the ledger?',
    body:
        'The ledger groups posted journal lines by account. Think of the journal as events in date order and the ledger as an account’s history. The Bank ledger shows the movements affecting Bank; the Capital ledger shows the movements affecting Capital.'
  ),
  (
    topic: 'Accounting basics',
    title: 'What is a balance sheet?',
    body:
        'A balance sheet shows what the business owns and owes at a particular date: Assets = Liabilities + Equity. Assets include cash, bank balances, customer receivables and equipment. Liabilities include money owed. Equity is the owners’ interest. In the 1,000 contribution example, Bank assets increase by 1,000 and Capital equity increases by 1,000.'
  ),
  (
    topic: 'Accounting basics',
    title: 'How is a trial balance different from a balance sheet?',
    body:
        'A trial balance lists ledger account balances and checks total debits against total credits. A balance sheet groups the relevant balances into assets, liabilities and equity. Balanced totals are a useful check, but do not guarantee every transaction uses the correct account.'
  ),
  (
    topic: 'Data & access',
    title: 'How does the data connect?',
    body:
        'Company → customers → invoices and invoice items → receipts and allocations. Accounting workflows create journals → journal lines → reports. Record identifiers connect these records. Names and references help you recognize them; changing a label does not create a new relationship.'
  ),
  (
    topic: 'Data & access',
    title: 'What happens when I am offline?',
    body:
        'Previously loaded data may be available from the local cache. Supported queued changes stay pending until the server accepts them. A pending change is not a confirmed accounting posting and does not update authoritative reports. Reconnect and check sync status before assuming a transaction is complete.'
  ),
  (
    topic: 'Data & access',
    title: 'Why can’t I see a section or save a record?',
    body:
        'Your role controls access. Ask your company administrator about missing sections or actions. For a form error, follow the message beside the field. Check required fields, dates and number formats. For pending or rejected sync, read the status before retrying so you do not create duplicate records.'
  ),
];

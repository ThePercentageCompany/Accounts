import 'package:flutter/material.dart';

/// A local guide: reading help never fetches or changes company records.
class WorkspaceHelp extends StatefulWidget {
  const WorkspaceHelp({super.key});

  @override
  State<WorkspaceHelp> createState() => _WorkspaceHelpState();
}

class _WorkspaceHelpState extends State<WorkspaceHelp> {
  String _query = '';
  String _topic = 'All';
  int _step = 0;

  static const _steps = [
    (
      Icons.people_outline,
      'Customer',
      'Who are you working with?',
      'Add the customer’s name and contact details in Customers. Invoices and receipts link back to this customer.'
    ),
    (
      Icons.description_outlined,
      'Invoice',
      'What are you selling?',
      'Create an invoice with items, quantities, prices and applicable tax. Review the draft, then issue it. Issuing creates the accounting journal; saving a draft does not.'
    ),
    (
      Icons.payments_outlined,
      'Receipt',
      'What has been paid?',
      'Record the customer’s payment and select the Cash or Bank account. Allocate the receipt to the appropriate invoices to update their outstanding balances.'
    ),
    (
      Icons.account_balance_outlined,
      'Reports',
      'How is the business doing?',
      'Posted journal lines feed the ledger, trial balance and financial reports. Check the report period and filters before interpreting the numbers.'
    ),
  ];

  static const _articles = <({String topic, String title, String body})>[
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final articles = _articles
        .where((a) =>
            (_topic == 'All' || a.topic == _topic) &&
            '${a.title} ${a.body}'
                .toLowerCase()
                .contains(_query.toLowerCase().trim()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('How to use')),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(colors: [
                        colors.primaryContainer,
                        colors.surfaceContainerLow
                      ]),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome_outlined,
                              color: colors.onPrimaryContainer, size: 32),
                          const SizedBox(height: 16),
                          Text('Your business, connected.',
                              style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          const Text(
                              'New here? Follow one sale from customer to report, then explore the answers below. No accounting experience needed.'),
                          const SizedBox(height: 16),
                          const Wrap(spacing: 8, runSpacing: 8, children: [
                            Chip(label: Text('Start with a customer')),
                            Chip(label: Text('Review before posting')),
                            Chip(label: Text('Track every payment')),
                          ]),
                        ]),
                  ),
                  const SizedBox(height: 28),
                  Text('Follow the flow', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                      'Select a step to see what it does and how it connects.'),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720
                        ? 4
                        : constraints.maxWidth >= 380
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      for (var i = 0; i < _steps.length; i++)
                        SizedBox(
                            width: width,
                            child: Semantics(
                              selected: _step == i,
                              child: Material(
                                color: _step == i
                                    ? colors.primaryContainer
                                    : colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => setState(() => _step = i),
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(_steps[i].$1,
                                              color: colors.primary),
                                          const SizedBox(height: 12),
                                          Text('${i + 1}. ${_steps[i].$2}',
                                              style:
                                                  theme.textTheme.titleMedium),
                                          const SizedBox(height: 4),
                                          Text(_steps[i].$3),
                                        ],
                                      )),
                                ),
                              ),
                            )),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (_step + 1) / _steps.length),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      semanticsLabel: 'Workflow step ${_step + 1} of 4',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16)),
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Align(
                          key: ValueKey(_step),
                          alignment: Alignment.centerLeft,
                          child: Text(_steps[_step].$4)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Find your answer', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      labelText: 'Search the guide',
                      hintText: 'Try ledger, invoice or offline',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final topic in [
                      'All',
                      'Getting started',
                      'Sales & payments',
                      'Accounting basics',
                      'Data & access'
                    ])
                      ChoiceChip(
                          label: Text(topic),
                          selected: _topic == topic,
                          onSelected: (_) => setState(() => _topic = topic)),
                  ]),
                  const SizedBox(height: 16),
                  if (articles.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No matching answers. Try a shorter search or select All.')),
                  for (final article in articles)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        key: PageStorageKey(article.title),
                        title: Text(article.title),
                        subtitle: Text(article.topic),
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(article.body)))
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                      'This guide explains the workflow. The sections and actions available in your workspace depend on your permissions.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

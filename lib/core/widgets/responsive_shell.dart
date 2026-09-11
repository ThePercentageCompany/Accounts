import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../auth/google_session.dart';
import 'brand_logo.dart';

class NavDestinationItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final String section;
  final Color pastelColor;

  const NavDestinationItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.section,
    required this.pastelColor,
  });
}

const List<NavDestinationItem> appNavDestinations = [
  NavDestinationItem(
    title: 'Dashboard',
    icon: CupertinoIcons.house_alt,
    selectedIcon: CupertinoIcons.house_alt_fill,
    section: 'CORE',
    pastelColor: Color(0xFF10B981),
  ),
  NavDestinationItem(
    title: 'Invoices',
    icon: CupertinoIcons.doc_text,
    selectedIcon: CupertinoIcons.doc_text_fill,
    section: 'FINANCIALS',
    pastelColor: Color(0xFF38BDF8),
  ),
  NavDestinationItem(
    title: 'Quotations',
    icon: CupertinoIcons.doc_plaintext,
    selectedIcon: CupertinoIcons.doc_on_clipboard_fill,
    section: 'FINANCIALS',
    pastelColor: Color(0xFF2DD4BF),
  ),
  NavDestinationItem(
    title: 'Income & Expenses',
    icon: CupertinoIcons.arrow_right_arrow_left_circle,
    selectedIcon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
    section: 'FINANCIALS',
    pastelColor: Color(0xFF10B981),
  ),
  NavDestinationItem(
    title: 'Capital & Equity',
    icon: CupertinoIcons.briefcase,
    selectedIcon: CupertinoIcons.briefcase_fill,
    section: 'ACCOUNTS',
    pastelColor: Color(0xFF8B5CF6),
  ),
  NavDestinationItem(
    title: 'Fixed Assets',
    icon: CupertinoIcons.cube_box,
    selectedIcon: CupertinoIcons.cube_box_fill,
    section: 'ACCOUNTS',
    pastelColor: Color(0xFFEC4899),
  ),
  NavDestinationItem(
    title: 'Balance Sheet',
    icon: CupertinoIcons.building_2_fill,
    selectedIcon: CupertinoIcons.building_2_fill,
    section: 'ACCOUNTS',
    pastelColor: Color(0xFF06B6D4),
  ),
  NavDestinationItem(
    title: 'Customers',
    icon: CupertinoIcons.person_2,
    selectedIcon: CupertinoIcons.person_2_fill,
    section: 'RELATIONSHIPS',
    pastelColor: Color(0xFF818CF8),
  ),
  NavDestinationItem(
    title: 'Employees',
    icon: CupertinoIcons.person_crop_circle_badge_checkmark,
    selectedIcon: CupertinoIcons.person_crop_circle_badge_checkmark,
    section: 'PEOPLE',
    pastelColor: Color(0xFF60A5FA),
  ),
  NavDestinationItem(
    title: 'Payroll',
    icon: CupertinoIcons.money_dollar,
    selectedIcon: CupertinoIcons.money_dollar_circle_fill,
    section: 'PEOPLE',
    pastelColor: Color(0xFF34D399),
  ),
  NavDestinationItem(
    title: 'Reports',
    icon: CupertinoIcons.chart_pie,
    selectedIcon: CupertinoIcons.chart_pie_fill,
    section: 'ANALYTICS',
    pastelColor: Color(0xFFF472B6),
  ),
  NavDestinationItem(
    title: 'Settings',
    icon: CupertinoIcons.gear_alt,
    selectedIcon: CupertinoIcons.gear_alt_fill,
    section: 'SYSTEM',
    pastelColor: Color(0xFF94A3B8),
  ),
];

class ResponsiveShell extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget child;
  final VoidCallback onNewInvoice;
  final VoidCallback onRefresh;
  final GoogleSession session;
  final bool isDemo;
  final String companyName;

  const ResponsiveShell({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.child,
    required this.onNewInvoice,
    required this.onRefresh,
    required this.session,
    required this.isDemo,
    this.companyName = 'The Percentage Company',
  });

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _showQuickSearchDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final matches = appNavDestinations
                .asMap()
                .entries
                .where((e) => e.value.title.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 420),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search invoices, customers, modules...',
                          prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (v) => setModalState(() => searchQuery = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final entry in matches)
                              ListTile(
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: entry.value.pastelColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(entry.value.icon, size: 16, color: entry.value.pastelColor),
                                ),
                                title: Text(
                                  entry.value.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(
                                  entry.value.section,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  widget.onIndexChanged(entry.key);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications & Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF10B981), size: 18),
                ),
                title: const Text('Workspace Synced', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: const Text('Google Sheets & Drive data is fully synchronized.', style: TextStyle(fontSize: 12)),
                trailing: const Text('Just now', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFF38BDF8), size: 18),
                ),
                title: const Text('New Invoice Generated', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: const Text('Invoice #INV-2024-001 created for BrightMind Ltd.', style: TextStyle(fontSize: 12)),
                trailing: const Text('2h ago', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.session.user?.displayName ?? 'Sarah Mitchell';
    final userEmail = widget.session.effectiveEmail.isNotEmpty ? widget.session.effectiveEmail : 'admin@percentage.com';

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(userEmail, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: Icon(isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon),
                title: Text(isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme'),
                onTap: () {
                  Navigator.pop(ctx);
                  themeController.toggleTheme();
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.arrow_2_circlepath),
                title: const Text('Sync Workspace Now'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onRefresh();
                },
              ),
              if (widget.session.workspace != null) ...[
                ListTile(
                  leading: const Icon(CupertinoIcons.table, color: Color(0xFF10B981)),
                  title: const Text('Open Google Sheet'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final url = widget.session.workspace!.spreadsheetUrl ??
                        'https://docs.google.com/spreadsheets/d/${widget.session.workspace!.spreadsheetId}/edit';
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  },
                ),
              ],
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAndSignOut(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.square_arrow_right, color: Color(0xFFEF4444), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.square_arrow_right, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Log Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your TPC Business account?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.session.signOut();
    }
  }

  void _showAccountsBottomSheet(BuildContext context, bool isDark) {
    final accountModules = [
      (index: 3, title: 'Income & Expenses', subtitle: 'Operating P&L, bills & cash', icon: CupertinoIcons.arrow_right_arrow_left_circle_fill, color: const Color(0xFF10B981)),
      (index: 4, title: 'Capital & Equity', subtitle: 'Shareholders & investments', icon: CupertinoIcons.briefcase_fill, color: const Color(0xFF8B5CF6)),
      (index: 5, title: 'Fixed Assets', subtitle: 'Depreciation & equipment', icon: CupertinoIcons.cube_box_fill, color: const Color(0xFFEC4899)),
      (index: 6, title: 'Balance Sheet', subtitle: 'General ledger & trial balance', icon: CupertinoIcons.building_2_fill, color: const Color(0xFF06B6D4)),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Accounts & Financial Statements',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final mod in accountModules) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onIndexChanged(mod.index);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.selectedIndex == mod.index
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                              : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.selectedIndex == mod.index
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: widget.selectedIndex == mod.index ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: mod.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(mod.icon, color: mod.color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mod.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mod.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickAddBottomSheet(BuildContext context, bool isDark) {
    final actions = [
      (title: 'Create Invoice', subtitle: 'Bill client & generate PDF', icon: CupertinoIcons.doc_text_fill, color: const Color(0xFF38BDF8), action: () => widget.onNewInvoice()),
      (title: 'Create Quotation', subtitle: 'Prepare proposal & estimation', icon: CupertinoIcons.doc_on_clipboard_fill, color: const Color(0xFF2DD4BF), action: () => widget.onIndexChanged(2)),
      (title: 'Record Expense / Income', subtitle: 'Add financial transaction', icon: CupertinoIcons.arrow_right_arrow_left_circle_fill, color: const Color(0xFF10B981), action: () => widget.onIndexChanged(3)),
      (title: 'Add Capital Contribution', subtitle: 'Shareholder investment entry', icon: CupertinoIcons.briefcase_fill, color: const Color(0xFF8B5CF6), action: () => widget.onIndexChanged(4)),
      (title: 'Register Fixed Asset', subtitle: 'Add hardware or equipment', icon: CupertinoIcons.cube_box_fill, color: const Color(0xFFEC4899), action: () => widget.onIndexChanged(5)),
      (title: 'Add New Customer', subtitle: 'Save client contact info', icon: CupertinoIcons.person_2_fill, color: const Color(0xFF818CF8), action: () => widget.onIndexChanged(7)),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final a in actions) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          a.action();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: a.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(a.icon, color: a.color, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      a.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                CupertinoIcons.arrow_up_right,
                                size: 16,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMoreBottomSheet(BuildContext context, bool isDark) {
    final sections = {
      'FINANCIALS': [0, 1, 2, 3],
      'ACCOUNTS & EQUITY': [4, 5, 6],
      'PEOPLE & OPERATIONS': [7, 8, 9],
      'SYSTEM & INSIGHTS': [10, 11],
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Business Modules',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final entry in sections.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final idx in entry.value)
                          _buildModuleGridCard(ctx, idx, isDark),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleGridCard(BuildContext ctx, int index, bool isDark) {
    final item = appNavDestinations[index];
    final isSelected = widget.selectedIndex == index;

    return SizedBox(
      width: (MediaQuery.sizeOf(ctx).width - 50) / 2,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          widget.onIndexChanged(index);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1E293B)
                : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF10B981)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : item.pastelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? Colors.white : item.pastelColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 980;
    final isTablet = width >= 700 && width < 980;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildSidebar(context, isDark),
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(context, isDark),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            _buildCompactRail(context, isDark),
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(context, isDark),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout
    final currentItem = appNavDestinations[widget.selectedIndex.clamp(0, appNavDestinations.length - 1)];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.line_horizontal_3, size: 22),
          tooltip: 'Open menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TpcBrandLogo(size: 24, borderRadius: 6),
            const SizedBox(width: 8),
            Text(
              currentItem.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.search, size: 20),
            tooltip: 'Search',
            onPressed: _showQuickSearchDialog,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.bell, size: 20),
            tooltip: 'Notifications',
            onPressed: () => _showNotificationsSheet(context),
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
              child: Text(
                (widget.session.user?.displayName?.isNotEmpty == true
                        ? widget.session.user!.displayName![0]
                        : 'S')
                    .toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ),
            tooltip: 'User menu',
            onPressed: () => _showUserMenu(context),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: _buildSidebar(context, true, isDrawer: true),
      ),
      body: widget.child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddBottomSheet(context, isDark),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        tooltip: 'Quick Action',
        child: const Icon(CupertinoIcons.plus, size: 24),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex < 3
            ? widget.selectedIndex
            : (widget.selectedIndex <= 6 ? 3 : 4),
        onDestinationSelected: (v) {
          if (v == 0) {
            widget.onIndexChanged(0);
          } else if (v == 1) {
            widget.onIndexChanged(1);
          } else if (v == 2) {
            widget.onIndexChanged(2);
          } else if (v == 3) {
            _showAccountsBottomSheet(context, isDark);
          } else {
            _showMoreBottomSheet(context, isDark);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(CupertinoIcons.house_alt),
            selectedIcon: Icon(CupertinoIcons.house_alt_fill),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(CupertinoIcons.doc_text),
            selectedIcon: Icon(CupertinoIcons.doc_text_fill),
            label: 'Invoices',
          ),
          const NavigationDestination(
            icon: Icon(CupertinoIcons.doc_plaintext),
            selectedIcon: Icon(CupertinoIcons.doc_on_clipboard_fill),
            label: 'Quotations',
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.briefcase),
            selectedIcon: const Icon(CupertinoIcons.briefcase_fill),
            label: (widget.selectedIndex >= 3 && widget.selectedIndex <= 6)
                ? currentItem.title
                : 'Accounts',
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.square_grid_2x2),
            selectedIcon: const Icon(CupertinoIcons.square_grid_2x2_fill),
            label: widget.selectedIndex > 6 ? currentItem.title : 'More',
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Top Header Bar
  // -------------------------------------------------------------
  Widget _buildTopHeader(BuildContext context, bool isDark) {
    final userName = widget.session.user?.displayName ?? 'Sarah Mitchell';
    final userRole = 'Admin';

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search Input Bar (⌘ K)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: InkWell(
                  onTap: _showQuickSearchDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 16,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search invoices, customers, or anything...',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '⌘ K',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Notification Bell with Red Dot
          InkWell(
            onTap: () => _showNotificationsSheet(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    CupertinoIcons.bell,
                    size: 21,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                  ),
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // User Profile Dropdown Pill
          InkWell(
            onTap: () => _showUserMenu(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        userRole,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Sidebar (Dark Slate Navy matching Mockup)
  // -------------------------------------------------------------
  Widget _buildSidebar(BuildContext context, bool isDark, {bool isDrawer = false}) {
    const sidebarBg = Color(0xFF0F172A);

    return Container(
      width: 250,
      color: sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Branding Header
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 22, bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        '%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'The',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Percentage',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Company',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation List Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: appNavDestinations.length,
                itemBuilder: (context, index) {
                  final item = appNavDestinations[index];
                  final isSelected = widget.selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: InkWell(
                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        widget.onIndexChanged(index);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 18,
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Sprout Card (*Good businesses grow with clarity*)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F2E23),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.leaf_arrow_circlepath,
                          size: 15,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Good businesses\ngrow with clarity.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Simple accounting\nfor a brighter tomorrow.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dedicated Logout Button in Sidebar & Drawer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: InkWell(
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  _confirmAndSignOut(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.square_arrow_right, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Log Out',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right, size: 12, color: Color(0xFFEF4444)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Compact Rail for Tablet
  // -------------------------------------------------------------
  Widget _buildCompactRail(BuildContext context, bool isDark) {
    const sidebarBg = Color(0xFF0F172A);

    return Container(
      width: 68,
      color: sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '%',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: appNavDestinations.length,
                itemBuilder: (context, index) {
                  final item = appNavDestinations[index];
                  final isSelected = widget.selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    child: Tooltip(
                      message: item.title,
                      child: InkWell(
                        onTap: () => widget.onIndexChanged(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 19,
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Logout Icon Button in Tablet Compact Rail
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Tooltip(
                message: 'Log Out',
                child: InkWell(
                  onTap: () => _confirmAndSignOut(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.square_arrow_right,
                        size: 19,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

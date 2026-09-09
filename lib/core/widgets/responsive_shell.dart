import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../auth/google_session.dart';
import '../sync/sync_manager.dart';
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
    title: 'Overview',
    icon: CupertinoIcons.chart_bar,
    selectedIcon: CupertinoIcons.chart_bar_fill,
    section: 'BILLING',
    pastelColor: AppTheme.pastelBlue,
  ),
  NavDestinationItem(
    title: 'Invoices',
    icon: CupertinoIcons.doc_text,
    selectedIcon: CupertinoIcons.doc_text_fill,
    section: 'BILLING',
    pastelColor: AppTheme.pastelMint,
  ),
  NavDestinationItem(
    title: 'Quotations',
    icon: CupertinoIcons.doc_text,
    selectedIcon: CupertinoIcons.doc_on_clipboard_fill,
    section: 'BILLING',
    pastelColor: AppTheme.pastelTeal,
  ),
  NavDestinationItem(
    title: 'Customers',
    icon: CupertinoIcons.person_2,
    selectedIcon: CupertinoIcons.person_2_fill,
    section: 'BILLING',
    pastelColor: AppTheme.pastelPurple,
  ),
  NavDestinationItem(
    title: 'Company',
    icon: CupertinoIcons.building_2_fill,
    selectedIcon: CupertinoIcons.building_2_fill,
    section: 'BILLING',
    pastelColor: AppTheme.pastelOrange,
  ),
  NavDestinationItem(
    title: 'Employees',
    icon: CupertinoIcons.person_crop_circle_badge_checkmark,
    selectedIcon: CupertinoIcons.person_crop_circle_badge_checkmark,
    section: 'OFFICE & HR',
    pastelColor: AppTheme.pastelIndigo,
  ),
  NavDestinationItem(
    title: 'Attendance',
    icon: CupertinoIcons.calendar,
    selectedIcon: CupertinoIcons.calendar_today,
    section: 'OFFICE & HR',
    pastelColor: AppTheme.pastelBlue,
  ),
  NavDestinationItem(
    title: 'Payroll',
    icon: CupertinoIcons.money_dollar_circle,
    selectedIcon: CupertinoIcons.money_dollar_circle_fill,
    section: 'OFFICE & HR',
    pastelColor: AppTheme.pastelMint,
  ),
  NavDestinationItem(
    title: 'Finance',
    icon: CupertinoIcons.creditcard,
    selectedIcon: CupertinoIcons.creditcard_fill,
    section: 'OFFICE & HR',
    pastelColor: AppTheme.pastelRose,
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
    this.companyName = 'TPC Business',
  });

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _showMoreBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final billingIndices = [for (int i = 0; i < appNavDestinations.length; i++) if (appNavDestinations[i].section == 'BILLING') i];
        final officeIndices = [for (int i = 0; i < appNavDestinations.length; i++) if (appNavDestinations[i].section == 'OFFICE & HR') i];

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
                        color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Business Modules',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.iosDarkTextPrimary : AppTheme.iosLightTextPrimary,
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

                  _buildSectionHeader('BILLING & INVOICING', isDark),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final idx in billingIndices) _buildModuleGridCard(ctx, idx, isDark),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildSectionHeader('OFFICE, HR & FINANCE', isDark),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final idx in officeIndices) _buildModuleGridCard(ctx, idx, isDark),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          themeController.toggleTheme();
                          Navigator.pop(ctx);
                        },
                        icon: Icon(isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon),
                        label: Text(isDark ? 'Switch to Light' : 'Switch to Dark'),
                      ),
                      if (!widget.isDemo && widget.session.user != null)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.session.signOut();
                          },
                          icon: const Icon(CupertinoIcons.square_arrow_right, color: AppTheme.pastelRose),
                          label: const Text('Sign Out', style: TextStyle(color: AppTheme.pastelRose)),
                        ),
                    ],
                  ),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? item.pastelColor.withValues(alpha: 0.25) : item.pastelColor.withValues(alpha: 0.15))
                : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? item.pastelColor
                  : (isDark ? const Color(0x20FFFFFF) : const Color(0x10000000)),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected
                      ? item.pastelColor
                      : item.pastelColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? Colors.white : item.pastelColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                    color: isSelected
                        ? (isDark ? Colors.white : AppTheme.iosLightTextPrimary)
                        : (isDark ? AppTheme.iosDarkTextPrimary : AppTheme.iosLightTextPrimary),
                    letterSpacing: -0.2,
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
    final isDesktop = width >= 960;
    final isTablet = width >= 700 && width < 960;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildSidebar(context, isDark),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    } else if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            _buildCompactRail(context, isDark),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // Mobile layout with top iOS navigation bar, drawer, and bottom tab bar
    final currentItem = appNavDestinations[widget.selectedIndex.clamp(0, appNavDestinations.length - 1)];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.line_horizontal_3, size: 22),
          tooltip: 'Open menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: currentItem.pastelColor.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(currentItem.icon, size: 14, color: currentItem.pastelColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currentItem.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon, size: 19),
            tooltip: 'Toggle theme',
            onPressed: () => themeController.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 19),
            tooltip: 'Refresh',
            onPressed: widget.onRefresh,
          ),
          if (widget.selectedIndex < 2)
            IconButton(
              icon: const Icon(CupertinoIcons.plus_circle_fill, size: 22, color: AppTheme.pastelBlue),
              tooltip: 'New invoice',
              onPressed: widget.onNewInvoice,
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? AppTheme.iosDarkBg : AppTheme.iosLightBg,
        child: _buildDrawerContent(context, isDark),
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex < 3 ? widget.selectedIndex : 3,
        onDestinationSelected: (v) {
          if (v < 3) {
            widget.onIndexChanged(v);
          } else {
            _showMoreBottomSheet(context, isDark);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(CupertinoIcons.chart_bar),
            selectedIcon: Icon(CupertinoIcons.chart_bar_fill),
            label: 'Overview',
          ),
          const NavigationDestination(
            icon: Icon(CupertinoIcons.doc_text),
            selectedIcon: Icon(CupertinoIcons.doc_text_fill),
            label: 'Invoices',
          ),
          const NavigationDestination(
            icon: Icon(CupertinoIcons.doc_text),
            selectedIcon: Icon(CupertinoIcons.doc_on_clipboard_fill),
            label: 'Quotations',
          ),
          NavigationDestination(
            icon: const Icon(CupertinoIcons.square_grid_2x2),
            selectedIcon: const Icon(CupertinoIcons.square_grid_2x2_fill),
            label: widget.selectedIndex >= 3 ? currentItem.title : 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isDark) {
    return Container(
      width: 260,
      color: isDark ? const Color(0xFF141416) : const Color(0xFFF7F7FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Branding
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const TpcBrandLogo(
                  size: 38,
                  borderRadius: 10,
                  showBackground: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.companyName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      ListenableBuilder(
                        listenable: widget.session.syncManager,
                        builder: (context, _) {
                          Color dotColor;
                          String statusText;
                          if (widget.isDemo) {
                            dotColor = AppTheme.pastelOrange;
                            statusText = 'Local Demo Mode';
                          } else if (widget.session.syncManager.status == SyncStatus.syncing) {
                            dotColor = AppTheme.pastelBlue;
                            statusText = 'Syncing with Google...';
                          } else if (widget.session.syncManager.pendingCount > 0) {
                            dotColor = AppTheme.pastelOrange;
                            statusText = '${widget.session.syncManager.pendingCount} Offline Changes';
                          } else if (widget.session.isOffline) {
                            dotColor = AppTheme.pastelOrange;
                            statusText = 'Offline Mode (Cached)';
                          } else {
                            dotColor = AppTheme.pastelMint;
                            statusText = 'Synced with Cloud';
                          }

                          return InkWell(
                            onTap: widget.onRefresh,
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Primary Quick Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton.icon(
              onPressed: widget.onNewInvoice,
              icon: const Icon(CupertinoIcons.plus_circle_fill, size: 18),
              label: const Text('New Invoice'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.pastelBlue,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSectionHeader('BILLING', isDark),
                for (int i = 0; i < appNavDestinations.length; i++)
                  if (appNavDestinations[i].section == 'BILLING')
                    _buildNavItem(context, i, isDark),
                const SizedBox(height: 16),
                _buildSectionHeader('OFFICE & FINANCE', isDark),
                for (int i = 0; i < appNavDestinations.length; i++)
                  if (appNavDestinations[i].section == 'OFFICE & HR')
                    _buildNavItem(context, i, isDark),
                const SizedBox(height: 16),
                _buildCloudStorageShortcuts(context, isDark),
              ],
            ),
          ),

          // Footer Actions: Theme Toggle, Sync, Profile
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: isDark ? 'Switch to Light mode' : 'Switch to Dark mode',
                  icon: Icon(isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon, size: 19),
                  onPressed: () => themeController.toggleTheme(),
                ),
                IconButton(
                  tooltip: 'Sync / Refresh data',
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 19),
                  onPressed: widget.onRefresh,
                ),
                const Spacer(),
                if (!widget.isDemo && (widget.session.user != null || widget.session.cachedEmail != null))
                  Tooltip(
                    message: 'Sign out (${widget.session.effectiveEmail})',
                    child: InkWell(
                      onTap: () => widget.session.signOut(),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: AppTheme.pastelBlue.withValues(alpha: 0.2),
                              child: Text(
                                (widget.session.effectiveEmail.isNotEmpty ? widget.session.effectiveEmail[0] : 'U').toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.pastelBlue),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(CupertinoIcons.square_arrow_right, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, bool isDark) {
    final item = appNavDestinations[index];
    final isSelected = widget.selectedIndex == index;

    final selectedBg = isDark
        ? item.pastelColor.withValues(alpha: 0.2)
        : item.pastelColor.withValues(alpha: 0.12);
    final selectedFg = item.pastelColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => widget.onIndexChanged(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? item.pastelColor
                      : item.pastelColor.withValues(alpha: isDark ? 0.15 : 0.1),
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
              const SizedBox(width: 12),
              Text(
                item.title,
                style: TextStyle(
                  color: isSelected ? selectedFg : (isDark ? AppTheme.iosDarkTextPrimary : AppTheme.iosLightTextPrimary),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRail(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onIndexChanged,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: IconButton.filled(
                    onPressed: widget.onNewInvoice,
                    icon: const Icon(CupertinoIcons.plus),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.pastelBlue),
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IconButton(
                        icon: Icon(isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon),
                        onPressed: () => themeController.toggleTheme(),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final item in appNavDestinations)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon, color: item.pastelColor),
                      label: Text(item.title),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildDrawerContent(BuildContext context, bool isDark) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const TpcBrandLogo(
                  size: 36,
                  borderRadius: 10,
                  showBackground: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.companyName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildSectionHeader('BILLING', isDark),
                for (int i = 0; i < appNavDestinations.length; i++)
                  if (appNavDestinations[i].section == 'BILLING')
                    _buildDrawerItem(context, i, isDark),
                const SizedBox(height: 12),
                _buildSectionHeader('OFFICE & FINANCE', isDark),
                for (int i = 0; i < appNavDestinations.length; i++)
                  if (appNavDestinations[i].section == 'OFFICE & HR')
                    _buildDrawerItem(context, i, isDark),
                const SizedBox(height: 12),
                _buildCloudStorageShortcuts(context, isDark),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => themeController.toggleTheme(),
                  icon: Icon(isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon),
                  label: Text(isDark ? 'Light' : 'Dark'),
                ),
                if (!widget.isDemo && (widget.session.user != null || widget.session.cachedEmail != null))
                  TextButton.icon(
                    onPressed: () => widget.session.signOut(),
                    icon: const Icon(CupertinoIcons.square_arrow_right, color: AppTheme.pastelRose),
                    label: const Text('Sign out', style: TextStyle(color: AppTheme.pastelRose)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, int index, bool isDark) {
    final item = appNavDestinations[index];
    final isSelected = widget.selectedIndex == index;

    return ListTile(
      leading: Icon(
        isSelected ? item.selectedIcon : item.icon,
        color: isSelected ? item.pastelColor : null,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? item.pastelColor : null,
          letterSpacing: -0.2,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context);
        widget.onIndexChanged(index);
      },
    );
  }

  Widget _buildCloudStorageShortcuts(BuildContext context, bool isDark) {
    final ws = widget.session.workspace;
    if (ws == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('GOOGLE CLOUD STORAGE', isDark),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: InkWell(
            onTap: () async {
              final url = ws.spreadsheetUrl ?? 'https://docs.google.com/spreadsheets/d/${ws.spreadsheetId}/edit';
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.pastelMintBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(CupertinoIcons.table, color: AppTheme.pastelMint, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Open Google Sheet',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.pastelMint),
                    ),
                  ),
                  const Icon(CupertinoIcons.arrow_up_right, size: 14, color: AppTheme.pastelMint),
                ],
              ),
            ),
          ),
        ),
        if (ws.driveFolderId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: InkWell(
              onTap: () async {
                final url = ws.folderUrl ?? 'https://drive.google.com/drive/folders/${ws.driveFolderId}';
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.pastelBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.folder_fill, color: AppTheme.pastelBlue, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Open Drive Folder',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.pastelBlue),
                      ),
                    ),
                    const Icon(CupertinoIcons.arrow_up_right, size: 14, color: AppTheme.pastelBlue),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/auth/company_onboarding_view.dart';
import 'core/auth/employee_login_view.dart';
import 'core/auth/google_session.dart';
import 'core/auth/workspace_sign_in_view.dart';
import 'core/theme/app_theme.dart';

import 'core/widgets/responsive_shell.dart';
import 'features/billing/data/hybrid_billing_repository.dart';
import 'features/billing/data/invoice_pdf.dart';
import 'features/billing/domain/billing_repository.dart';
import 'features/billing/domain/invoice_document_service.dart';
import 'features/billing/domain/models.dart';
import 'features/billing/presentation/billing_cubit.dart';
import 'features/billing/presentation/dashboard_view.dart';
import 'features/billing/presentation/screens.dart';
import 'features/billing/presentation/editors.dart';
import 'features/office/data/hybrid_office_repository.dart';
import 'features/office/data/pdf_office_documents.dart';
import 'features/office/domain/office_documents.dart';
import 'features/office/domain/office_repository.dart';
import 'features/office/presentation/office_cubit.dart';
import 'features/office/presentation/office_screen.dart';
import 'features/office/presentation/capital_equity_screen.dart';
import 'features/office/presentation/assets_screen.dart';
import 'features/office/presentation/balance_sheet_screen.dart';
import 'features/reports/presentation/reports_hub_screen.dart';
import 'features/quotations/data/hybrid_quotation_repository.dart';
import 'features/quotations/data/quotation_pdf.dart';
import 'features/quotations/domain/quotation_document_service.dart';
import 'features/quotations/domain/quotation_repository.dart';
import 'features/quotations/presentation/quotation_cubit.dart';
import 'features/quotations/presentation/quotations_screen.dart';

final session = GoogleSession();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  try {
    await themeController.initialize();
    await session.initialize();
    runApp(const TpcApp());
  } catch (e) {
    runApp(const TpcApp());
  }
}

class TpcApp extends StatelessWidget {
  const TpcApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GoogleSession>.value(value: session),
          RepositoryProvider<InvoiceDocumentService>(create: (_) => PdfInvoiceDocumentService()),
          RepositoryProvider<QuotationDocumentService>(create: (_) => PdfQuotationDocumentService()),
          RepositoryProvider<OfficeDocuments>(create: (_) => PdfOfficeDocuments()),
        ],
        child: ListenableBuilder(
          listenable: themeController,
          builder: (context, _) => MaterialApp(
            title: 'TPC Business',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeController.themeMode,
            home: ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                // A scanned employee QR always takes precedence over a cached
                // workspace so the employee can confirm their own access code.
                if (session.pendingEmployeeInvite != null || session.employeeLoginRequested) {
                  return EmployeeLoginView(session: session);
                }

                if (session.workspace != null) {
                  // Recreate repositories and cached screen data when the
                  // signed-in identity or server-assigned permissions change.
                  return Workspace(key: ValueKey((
                    session.workspace!.spreadsheetId,
                    session.isEmployee,
                    session.currentEmployeeId,
                    session.currentEmployeeRole,
                    session.allowedSections?.join('|'),
                  )));
                }

                if (session.isCheckingWorkspace) {
                  return const WorkspaceLoadingView();
                }

                if (session.authorized) {
                  return CompanyOnboardingView(session: session);
                }

                return const GoogleLogin();
              },
            ),
          ),
        ),
      );
}

class WorkspaceLoadingView extends StatelessWidget {
  const WorkspaceLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.iosDarkBg : AppTheme.iosLightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.pastelMintBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CupertinoActivityIndicator(radius: 14, color: AppTheme.pastelMint),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connecting to Google Cloud...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Searching your Google Drive & Sheets workspace',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Workspace extends StatefulWidget {
  const Workspace({super.key});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _openWorkspace();
  }

  Future<void> _openWorkspace() async {
    // Always attempt a live Sheets pull when the workspace opens. If the
    // browser is offline, syncNow preserves the pending queue and the cached
    // records remain available instead of blocking the user.
    try {
      await session.syncNow();
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const WorkspaceLoadingView();
    // Unified hybrid repositories: offline-first local storage + automatic
    // background cloud sync — no mode switching needed.
    final BillingRepository billingRepo = HybridBillingRepository(session);
    final OfficeRepository officeRepo = HybridOfficeRepository(session);
    final QuotationRepository quotationRepo = HybridQuotationRepository(session);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => BillingCubit(billingRepo)..refresh()),
        BlocProvider(create: (_) => OfficeCubit(officeRepo)..run()),
        BlocProvider(create: (_) => QuotationCubit(quotationRepo)..refresh()),
      ],
      child: const AppWorkspaceShell(),
    );
  }
}

class AppWorkspaceShell extends StatefulWidget {
  const AppWorkspaceShell({super.key});

  @override
  State<AppWorkspaceShell> createState() => _AppWorkspaceShellState();
}

class _AppWorkspaceShellState extends State<AppWorkspaceShell> {
  int navIndex = 0;
  late int _displayedRevision;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    _displayedRevision = session.syncManager.dataRevision;
    session.syncManager.addListener(_onSyncedData);
  }

  @override
  void dispose() {
    session.syncManager.removeListener(_onSyncedData);
    super.dispose();
  }

  void _onSyncedData() {
    final sync = session.syncManager;
    if (!mounted || _refreshQueued || sync.isBackgroundSyncing ||
        sync.dataRevision == _displayedRevision) {
      return;
    }
    _refreshQueued = true;
    Future<void>.microtask(() async {
      try {
        if (!mounted) return;
        final billing = context.read<BillingCubit>();
        final office = context.read<OfficeCubit>();
        final quotations = context.read<QuotationCubit>();
        if (billing.state.busy || office.state.busy || quotations.state.busy) return;
        _displayedRevision = sync.dataRevision;
        await Future.wait([
          billing.refresh(), office.run(), quotations.refresh(),
        ]);
      } finally {
        _refreshQueued = false;
      }
    });
  }

  Future<void> openEditor([Invoice? invoice]) async {
    if (!session.isSectionAllowed('Invoices')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your role does not allow creating invoices.')),
      );
      return;
    }
    final cubit = context.read<BillingCubit>();
    if (cubit.state.data.customers.isEmpty) {
      if (session.isSectionAllowed('Customers')) setState(() => navIndex = 7);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a customer before creating an invoice.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: InvoiceEditor(invoice: invoice),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillingCubit, BillingState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), duration: const Duration(seconds: 7)),
          );
        }
      },
      builder: (context, billingState) {
        final billingCubit = context.read<BillingCubit>();
        final officeCubit = context.read<OfficeCubit>();
        final quotationCubit = context.read<QuotationCubit>();
        final isDemo = billingCubit.repository.isDemo;
        final companyName = billingState.data.company.name.isNotEmpty
            ? billingState.data.company.name
            : (session.workspace?.companyName ?? 'TPC Business');
        final selectedDestination = appNavDestinations[navIndex];
        final effectiveNavIndex = session.isSectionAllowed(selectedDestination.title)
            ? navIndex
            : appNavDestinations.indexWhere((item) => session.isSectionAllowed(item.title));

        Widget body;
        switch (effectiveNavIndex) {
          case 0:
            body = DashboardView(
              onNewInvoice: () => openEditor(),
              onNavigate: (idx) => setState(() => navIndex = idx),
            );
            break;
          case 1:
            body = InvoicesView(onNewInvoice: () => openEditor(), isOverview: false);
            break;
          case 2:
            body = const QuotationsView();
            break;
          case 3:
            body = const OfficeScreen(key: ValueKey('office-fin'), initialPage: 3);
            break;
          case 4:
            body = const CapitalEquityScreen();
            break;
          case 5:
            body = const AssetsScreen();
            break;
          case 6:
            body = const BalanceSheetScreen();
            break;
          case 7:
            body = const CustomersView();
            break;
          case 8:
            body = const OfficeScreen(key: ValueKey('office-emp'), initialPage: 0);
            break;
          case 9:
            body = const OfficeScreen(key: ValueKey('office-pay'), initialPage: 2);
            break;
          case 10:
            body = const ReportsHubScreen();
            break;
          case 11:
            body = CompanyEditor(company: billingState.data.company);
            break;
          case 12:
            body = const OfficeScreen(key: ValueKey('office-attendance'), initialPage: 1);
            break;
          default:
            body = const Center(child: Text('No sections are assigned. Contact your company owner.'));
        }

        return ResponsiveShell(
          selectedIndex: effectiveNavIndex,
          onIndexChanged: (idx) {
            if (session.isSectionAllowed(appNavDestinations[idx].title)) {
              setState(() => navIndex = idx);
            }
          },
          onNewInvoice: () => openEditor(),
          onRefresh: () async {
            await billingCubit.refresh();
            if (context.mounted) {
              await officeCubit.run();
              await quotationCubit.refresh();
            }
          },
          session: session,
          isDemo: isDemo,
          companyName: companyName,
          child: ListenableBuilder(
            listenable: session.syncManager,
            builder: (context, _) => Column(
              children: [
                if (session.syncManager.lastError != null)
                  MaterialBanner(
                    content: Text('Google sync needs attention. ${session.syncManager.lastError}'),
                    actions: [
                      TextButton(
                        onPressed: session.syncManager.isBackgroundSyncing ? null : () async {
                          try {
                            await session.syncNow();
                          } catch (_) {
                            // The sync manager keeps the failure visible here.
                          }
                        },
                        child: const Text('Retry sync'),
                      ),
                    ],
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GoogleLogin extends StatelessWidget {
  const GoogleLogin({super.key});

  @override
  Widget build(BuildContext context) => WorkspaceSignInView(session: session);
}
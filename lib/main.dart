import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/auth/company_onboarding_view.dart';
import 'core/auth/google_session.dart';
import 'core/auth/sign_in_button.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/brand_logo.dart';
import 'core/widgets/responsive_shell.dart';
import 'features/billing/data/google_direct_repository.dart';
import 'features/billing/data/local_repository.dart';
import 'features/billing/data/invoice_pdf.dart';
import 'features/billing/domain/billing_repository.dart';
import 'features/billing/domain/invoice_document_service.dart';
import 'features/billing/domain/models.dart';
import 'features/billing/presentation/billing_cubit.dart';
import 'features/billing/presentation/dashboard_view.dart';
import 'features/billing/presentation/screens.dart';
import 'features/billing/presentation/editors.dart';
import 'features/office/data/google_direct_office_repository.dart';
import 'features/office/data/local_office_repository.dart';
import 'features/office/data/pdf_office_documents.dart';
import 'features/office/domain/office_documents.dart';
import 'features/office/domain/office_repository.dart';
import 'features/office/presentation/office_cubit.dart';
import 'features/office/presentation/office_screen.dart';
import 'features/office/presentation/capital_equity_screen.dart';
import 'features/office/presentation/assets_screen.dart';
import 'features/office/presentation/balance_sheet_screen.dart';
import 'features/reports/presentation/reports_hub_screen.dart';
import 'features/quotations/data/google_direct_quotation_repository.dart';
import 'features/quotations/data/local_quotation_repository.dart';
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
                if (session.workspace != null) {
                  return Workspace(key: ValueKey(session.workspace!.spreadsheetId));
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

class Workspace extends StatelessWidget {
  const Workspace({super.key});

  @override
  Widget build(BuildContext context) {
    final isLocalWorkspace = session.workspace == null ||
        session.workspace!.spreadsheetId == 'local_demo_workspace' ||
        session.workspace!.spreadsheetId.isEmpty;

    final BillingRepository billingRepo = !isLocalWorkspace
        ? GoogleDirectBillingRepository(session)
        : LocalRepository();

    final OfficeRepository officeRepo = !isLocalWorkspace
        ? GoogleDirectOfficeRepository(session)
        : LocalOfficeRepository();

    final QuotationRepository quotationRepo = !isLocalWorkspace
        ? GoogleDirectQuotationRepository(session)
        : LocalQuotationRepository();

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

  Future<void> openEditor([Invoice? invoice]) async {
    final cubit = context.read<BillingCubit>();
    if (cubit.state.data.customers.isEmpty) {
      setState(() => navIndex = 4);
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

        Widget body;
        switch (navIndex) {
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
          default:
            body = DashboardView(
              onNewInvoice: () => openEditor(),
              onNavigate: (idx) => setState(() => navIndex = idx),
            );
        }

        return ResponsiveShell(
          selectedIndex: navIndex,
          onIndexChanged: (idx) => setState(() => navIndex = idx),
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
          child: body,
        );
      },
    );
  }
}

class GoogleLogin extends StatelessWidget {
  const GoogleLogin({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.iosDarkBg : AppTheme.iosLightBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: TpcBrandLogo(
                        size: 76,
                        borderRadius: 20,
                        showBackground: true,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'The Percentage Company',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Executive Invoicing, Quotations, HR, Payroll and Corporate Finance Suite.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (session.user == null)
                      Column(
                        children: [
                          Center(child: googleButton(() => session.signIn())),
                          const SizedBox(height: 16),
                          Text(
                            'Sign in securely with your Google account',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                                  thickness: 0.5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                                  thickness: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => session.useOfflineDemo(),
                              icon: const Icon(CupertinoIcons.device_laptop, size: 18),
                              label: const Text(
                                'Continue with Local / Offline Storage',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : AppTheme.iosLightTextPrimary,
                                side: BorderSide(
                                  color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                                  width: 0.8,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Work entirely on this device without cloud sync.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.iosDarkSurfaceElevated : AppTheme.iosLightSurfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.pastelIndigoBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                CupertinoIcons.person_crop_circle_fill,
                                color: AppTheme.pastelIndigo,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Signed in as',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    session.user!.email,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: session.isAuthorizing ? null : () => session.authorize(),
                        icon: session.isAuthorizing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(CupertinoIcons.arrow_right_circle_fill, size: 20),
                        label: Text(
                          session.isAuthorizing ? 'Connecting Google Workspace...' : 'Continue to Workspace ➔',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.pastelMint,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Connects your Google Sheets & Drive to store company data.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => session.signOut(),
                        icon: const Icon(CupertinoIcons.arrow_left, size: 14),
                        label: const Text('Use a different Google account', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                        ),
                      ),
                    ],
                    if (session.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelRoseBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.pastelRose.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.exclamationmark_circle_fill, color: AppTheme.pastelRose, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                session.error!,
                                style: const TextStyle(color: AppTheme.pastelRose, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


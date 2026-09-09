import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../features/billing/domain/models.dart';
import 'google_session.dart';
import 'google_workspace_service.dart';

class CompanyOnboardingView extends StatefulWidget {
  final GoogleSession session;

  const CompanyOnboardingView({super.key, required this.session});

  @override
  State<CompanyOnboardingView> createState() => _CompanyOnboardingViewState();
}

class _CompanyOnboardingViewState extends State<CompanyOnboardingView> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(text: 'The Percentage Company');
  final _addressController = TextEditingController(text: 'Business Bay, Downtown Dubai, UAE');
  final _phoneController = TextEditingController(text: '+971 4 000 0000');
  final _emailController = TextEditingController();
  final _trnController = TextEditingController(text: '100294857600003');
  final _invoicePrefixController = TextEditingController(text: 'INV-');
  final _quotationPrefixController = TextEditingController(text: 'QTN-');
  final _bankNameController = TextEditingController(text: 'Emirates NBD');
  final _accountNameController = TextEditingController(text: 'The Percentage Company LLC');
  final _ibanController = TextEditingController(text: 'AE000000000000000000000');
  final _swiftController = TextEditingController(text: 'EBILAEADXXX');
  final _currencyController = TextEditingController(text: 'AED');
  final _adminEmailController = TextEditingController(text: defaultMasterAdminEmail);

  bool _isProvisioning = false;
  String _progressStatus = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.session.user?.email != null) {
      _emailController.text = widget.session.user!.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _trnController.dispose();
    _invoicePrefixController.dispose();
    _quotationPrefixController.dispose();
    _bankNameController.dispose();
    _accountNameController.dispose();
    _ibanController.dispose();
    _swiftController.dispose();
    _currencyController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  Future<void> _startProvisioning() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProvisioning = true;
      _errorMessage = null;
      _progressStatus = 'Initializing workspace setup...';
    });

    try {
      final token = await widget.session.token();

      final company = Company(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        trn: _trnController.text.trim(),
        prefix: _invoicePrefixController.text.trim().isNotEmpty ? _invoicePrefixController.text.trim() : 'TPC',
        bank: _bankNameController.text.trim(),
        accountHolder: _accountNameController.text.trim(),
        accountNumber: _swiftController.text.trim(),
        iban: _ibanController.text.trim(),
      );

      final service = GoogleWorkspaceService();
      final config = await service.provisionWorkspace(
        accessToken: token,
        company: company,
        masterEmail: _adminEmailController.text.trim(),
        onProgress: (status) {
          if (mounted) {
            setState(() => _progressStatus = status);
          }
        },
      );

      if (mounted) {
        await widget.session.setWorkspace(config);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
          _isProvisioning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.iosDarkBg : AppTheme.iosLightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
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
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            const TpcBrandLogo(
                              size: 52,
                              borderRadius: 16,
                              showBackground: true,
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Workspace Setup',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Setup your company details & private Google Cloud storage.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelMintBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.pastelMint.withValues(alpha: 0.2), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.checkmark_shield_fill, color: AppTheme.pastelMint, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Signed in as ${widget.session.user?.email ?? 'Google User'}. We will create a private Google Sheet and Drive folder directly in your personal Google account.',
                                  style: const TextStyle(color: AppTheme.pastelMint, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Company Profile
                        _buildSectionHeader('Company Profile', CupertinoIcons.building_2_fill, isDark),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Company Legal Name',
                          hint: 'e.g. The Percentage Company LLC',
                          icon: CupertinoIcons.briefcase,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required' : null,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _trnController,
                                label: 'Tax Registration / TRN',
                                hint: '100293847500003',
                                icon: CupertinoIcons.number,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _currencyController,
                                label: 'Currency',
                                hint: 'AED',
                                icon: CupertinoIcons.money_dollar,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Registered Office Address',
                          hint: 'Office 102, Prime Tower, Business Bay, Dubai, UAE',
                          icon: CupertinoIcons.location,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _emailController,
                                label: 'Billing / Contact Email',
                                hint: 'billing@company.com',
                                icon: CupertinoIcons.mail,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                hint: '+971 4 000 0000',
                                icon: CupertinoIcons.phone,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        // Section 2: Document Prefixes
                        _buildSectionHeader('Document Prefixes', CupertinoIcons.doc_text_fill, isDark),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _invoicePrefixController,
                                label: 'Invoice Prefix',
                                hint: 'INV-',
                                icon: CupertinoIcons.doc_plaintext,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _quotationPrefixController,
                                label: 'Quotation Prefix',
                                hint: 'QTN-',
                                icon: CupertinoIcons.doc_text,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        // Section 3: Banking Details
                        _buildSectionHeader('Banking & Remittance Details', CupertinoIcons.creditcard_fill, isDark),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _bankNameController,
                                label: 'Bank Name',
                                hint: 'Emirates NBD',
                                icon: CupertinoIcons.building_2_fill,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _swiftController,
                                label: 'SWIFT / BIC Code',
                                hint: 'EBILAEADXXX',
                                icon: CupertinoIcons.barcode,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _accountNameController,
                          label: 'Account Beneficiary Name',
                          hint: 'The Percentage Company LLC',
                          icon: CupertinoIcons.person,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _ibanController,
                          label: 'IBAN Number',
                          hint: 'AE000000000000000000000',
                          icon: CupertinoIcons.creditcard,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 24),
                        // Section 4: Auto Share Permission
                        _buildSectionHeader('Master Admin View Access', CupertinoIcons.eye_fill, isDark),
                        const SizedBox(height: 8),
                        Text(
                          'A read-only view permission will automatically be granted to the master admin email below for cross-company executive review.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _adminEmailController,
                          label: 'Admin / Reviewer Email',
                          hint: 'thepercentagecompany1@gmail.com',
                          icon: CupertinoIcons.person_badge_plus,
                          isDark: isDark,
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 20),
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
                                    _errorMessage!,
                                    style: const TextStyle(color: AppTheme.pastelRose, fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Progress loader
                        if (_isProvisioning) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.iosDarkSurfaceElevated : AppTheme.iosLightSurfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder, width: 0.5),
                            ),
                            child: Column(
                              children: [
                                const LinearProgressIndicator(
                                  backgroundColor: AppTheme.pastelMintBg,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.pastelMint),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CupertinoActivityIndicator(),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        _progressStatus,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),
                        // Action Buttons
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _isProvisioning ? null : () => widget.session.signOut(),
                              icon: const Icon(CupertinoIcons.arrow_left, size: 16),
                              label: const Text('Sign Out'),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _isProvisioning ? null : _startProvisioning,
                              icon: const Icon(CupertinoIcons.cloud_upload_fill, size: 18),
                              label: const Text('Provision Google Workspace', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.pastelMint,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.pastelIndigo),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isDark = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
        isDense: true,
        filled: true,
        fillColor: isDark ? AppTheme.iosDarkSurfaceElevated : AppTheme.iosLightSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.pastelMint, width: 1.5),
        ),
      ),
    );
  }
}

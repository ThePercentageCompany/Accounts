import 'package:flutter/material.dart';

class AppTheme {
  // -------------------------------------------------------------
  // Zoho Books / Zoho Finance Color Palette
  // -------------------------------------------------------------
  // Primary Zoho Colors
  static const Color zohoBlue = Color(0xFF1B68D0); // Zoho Books Action Blue
  static const Color zohoBlueDark = Color(0xFF1351A8);
  static const Color zohoBlueBg = Color(0xFFEBF3FC);
  static const Color zohoBlueBgDark = Color(0xFF0F264A);

  static const Color zohoRed = Color(0xFFE42528); // Zoho Corporate Red
  static const Color zohoRedDark = Color(0xFFC61B1E);
  static const Color zohoRedBg = Color(0xFFFDE8E8);
  static const Color zohoRedBgDark = Color(0xFF450A0A);

  static const Color zohoGreen = Color(0xFF10B981); // Zoho Emerald / Paid
  static const Color zohoGreenDark = Color(0xFF059669);
  static const Color zohoGreenBg = Color(0xFFECFDF5);
  static const Color zohoGreenBgDark = Color(0xFF064E3B);

  static const Color zohoAmber = Color(0xFFF59E0B); // Zoho Warning / Pending
  static const Color zohoAmberDark = Color(0xFFD97706);
  static const Color zohoAmberBg = Color(0xFFFFFBEB);
  static const Color zohoAmberBgDark = Color(0xFF78350F);

  static const Color zohoPurple = Color(0xFF7C3AED); // Zoho Purple / Capital
  static const Color zohoPurpleBg = Color(0xFFF5F3FF);
  static const Color zohoPurpleBgDark = Color(0xFF2E1065);

  static const Color zohoCyan = Color(0xFF0284C7); // Zoho Cyan / Info
  static const Color zohoCyanBg = Color(0xFFE0F2FE);
  static const Color zohoCyanBgDark = Color(0xFF0C4A6E);

  // Backwards compatible aliases
  static const Color pastelMint = zohoGreen;
  static const Color pastelMintBg = zohoGreenBg;
  static const Color pastelMintBgDark = zohoGreenBgDark;

  static const Color pastelBlue = zohoBlue;
  static const Color pastelBlueBg = zohoBlueBg;
  static const Color pastelBlueBgDark = zohoBlueBgDark;

  static const Color pastelPurple = zohoPurple;
  static const Color pastelPurpleBg = zohoPurpleBg;
  static const Color pastelPurpleBgDark = zohoPurpleBgDark;

  static const Color pastelOrange = zohoAmber;
  static const Color pastelOrangeBg = zohoAmberBg;
  static const Color pastelOrangeBgDark = zohoAmberBgDark;

  static const Color pastelRose = zohoRed;
  static const Color pastelRoseBg = zohoRedBg;
  static const Color pastelRoseBgDark = zohoRedBgDark;

  static const Color pastelIndigo = Color(0xFF4F46E5);
  static const Color pastelIndigoBg = Color(0xFFEEF2FF);
  static const Color pastelIndigoBgDark = Color(0xFF1E1B4B);

  static const Color pastelTeal = zohoCyan;
  static const Color pastelTealBg = zohoCyanBg;
  static const Color pastelTealBgDark = zohoCyanBgDark;

  // -------------------------------------------------------------
  // Zoho Backgrounds & Surfaces
  // -------------------------------------------------------------
  // Light Mode (Zoho Books Signature Canvas)
  static const Color zohoLightBg = Color(0xFFF4F6F9); // Clean SaaS Light Slate Canvas
  static const Color zohoLightSurface = Color(0xFFFFFFFF); // Pure White Card Surface
  static const Color zohoLightSurfaceElevated = Color(0xFFF8FAFC); // Table Header / Subtle surface
  static const Color zohoLightBorder = Color(0xFFE2E8F0); // Crisp 1px card border
  static const Color zohoLightSeparator = Color(0xFFEAECF0);
  static const Color zohoLightTextPrimary = Color(0xFF0F172A); // High-contrast Charcoal Slate
  static const Color zohoLightTextSecondary = Color(0xFF475569); // Clean Secondary Slate
  static const Color zohoLightTextMuted = Color(0xFF94A3B8);

  // Backward compatible aliases
  static const Color iosLightBg = zohoLightBg;
  static const Color iosLightSurface = zohoLightSurface;
  static const Color iosLightSurfaceElevated = zohoLightSurfaceElevated;
  static const Color iosLightBorder = zohoLightBorder;
  static const Color iosLightSeparator = zohoLightSeparator;
  static const Color iosLightTextPrimary = zohoLightTextPrimary;
  static const Color iosLightTextSecondary = zohoLightTextSecondary;

  // Dark Mode (Zoho Books Dark Navy)
  static const Color zohoDarkBg = Color(0xFF0B1120); // Deep Dark Slate Canvas
  static const Color zohoDarkSurface = Color(0xFF1E293B); // Dark Slate Card Surface
  static const Color zohoDarkSurfaceElevated = Color(0xFF162032);
  static const Color zohoDarkBorder = Color(0xFF334155);
  static const Color zohoDarkSeparator = Color(0xFF243044);
  static const Color zohoDarkTextPrimary = Color(0xFFF8FAFC);
  static const Color zohoDarkTextSecondary = Color(0xFF94A3B8);
  static const Color zohoDarkTextMuted = Color(0xFF64748B);

  // Backward compatible aliases
  static const Color iosDarkBg = zohoDarkBg;
  static const Color iosDarkSurface = zohoDarkSurface;
  static const Color iosDarkSurfaceElevated = zohoDarkSurfaceElevated;
  static const Color iosDarkBorder = zohoDarkBorder;
  static const Color iosDarkSeparator = zohoDarkSeparator;
  static const Color iosDarkTextPrimary = zohoDarkTextPrimary;
  static const Color iosDarkTextSecondary = zohoDarkTextSecondary;

  // -------------------------------------------------------------
  // Zoho Card Curves & Geometry Tokens
  // -------------------------------------------------------------
  static const double cardRadiusVal = 10.0;
  static const double buttonRadiusVal = 8.0;
  static const double inputRadiusVal = 8.0;
  static const double badgeRadiusVal = 6.0;

  static final BorderRadius cardRadius = BorderRadius.circular(cardRadiusVal);
  static final BorderRadius buttonRadius = BorderRadius.circular(buttonRadiusVal);
  static final BorderRadius inputRadius = BorderRadius.circular(inputRadiusVal);
  static final BorderRadius badgeRadius = BorderRadius.circular(badgeRadiusVal);

  /// Signature Zoho Card BoxDecoration with 10px curve, 1px crisp border, and subtle elevation
  static BoxDecoration zohoCardDecoration(
    bool isDark, {
    Color? customBg,
    Color? customBorder,
    double radius = cardRadiusVal,
    bool showShadow = true,
  }) {
    return BoxDecoration(
      color: customBg ?? (isDark ? zohoDarkSurface : zohoLightSurface),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: customBorder ?? (isDark ? zohoDarkBorder : zohoLightBorder),
        width: 1.0,
      ),
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  // -------------------------------------------------------------
  // Theme Builder: Light
  // -------------------------------------------------------------
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary: zohoBlue,
      onPrimary: Colors.white,
      primaryContainer: zohoBlueBg,
      onPrimaryContainer: zohoBlueDark,
      secondary: zohoRed,
      onSecondary: Colors.white,
      secondaryContainer: zohoRedBg,
      onSecondaryContainer: zohoRedDark,
      surface: zohoLightSurface,
      onSurface: zohoLightTextPrimary,
      error: zohoRed,
      onError: Colors.white,
      outline: zohoLightBorder,
      outlineVariant: zohoLightSeparator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: zohoLightBg,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Plus Jakarta Sans', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      appBarTheme: const AppBarTheme(
        backgroundColor: zohoLightSurface,
        foregroundColor: zohoLightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: zohoLightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: zohoLightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusVal),
          side: const BorderSide(color: zohoLightBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoLightBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoLightBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoRed, width: 1.2),
        ),
        labelStyle: const TextStyle(color: zohoLightTextSecondary, fontSize: 13.5, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: zohoLightTextMuted, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: zohoBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: zohoBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zohoLightTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: zohoLightBorder, width: 1.0),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: zohoBlue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: zohoLightSurface,
        elevation: 0,
        indicatorColor: zohoBlueBg,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: zohoBlue, size: 22);
          }
          return const IconThemeData(color: zohoLightTextSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: zohoBlue, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: -0.1, fontFamily: 'Inter');
          }
          return const TextStyle(color: zohoLightTextSecondary, fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: -0.1, fontFamily: 'Inter');
        }),
      ),
      dividerTheme: const DividerThemeData(color: zohoLightSeparator, thickness: 1.0, space: 16),
    );
  }

  // -------------------------------------------------------------
  // Theme Builder: Dark
  // -------------------------------------------------------------
  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      primary: zohoBlue,
      onPrimary: Colors.white,
      primaryContainer: zohoBlueBgDark,
      onPrimaryContainer: Colors.white,
      secondary: zohoRed,
      onSecondary: Colors.white,
      secondaryContainer: zohoRedBgDark,
      onSecondaryContainer: Colors.white,
      surface: zohoDarkSurface,
      onSurface: zohoDarkTextPrimary,
      error: zohoRed,
      onError: Colors.white,
      outline: zohoDarkBorder,
      outlineVariant: zohoDarkSeparator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: zohoDarkBg,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Plus Jakarta Sans', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      appBarTheme: const AppBarTheme(
        backgroundColor: zohoDarkSurface,
        foregroundColor: zohoDarkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: zohoDarkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: zohoDarkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusVal),
          side: const BorderSide(color: zohoDarkBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zohoDarkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoDarkBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoDarkBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoRed, width: 1.2),
        ),
        labelStyle: const TextStyle(color: zohoDarkTextSecondary, fontSize: 13.5, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: zohoDarkTextMuted, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: zohoBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: zohoBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zohoDarkTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: zohoDarkBorder, width: 1.0),
          backgroundColor: zohoDarkSurfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF60A5FA),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadiusVal)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: -0.1, fontFamily: 'Inter'),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: zohoDarkSurface,
        elevation: 0,
        indicatorColor: zohoBlueBgDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: zohoBlue, size: 22);
          }
          return const IconThemeData(color: zohoDarkTextSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: -0.1, fontFamily: 'Inter');
          }
          return const TextStyle(color: zohoDarkTextSecondary, fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: -0.1, fontFamily: 'Inter');
        }),
      ),
      dividerTheme: const DividerThemeData(color: zohoDarkSeparator, thickness: 1.0, space: 16),
    );
  }
}

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

final themeController = ThemeController();

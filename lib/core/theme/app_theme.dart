import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static TextTheme _typography(Color color) => TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -.8,
          color: color,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -.6,
          color: color,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
          color: color,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          color: color,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: color),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: color),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: color),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ).apply(fontFamily: 'Inter');

  // -------------------------------------------------------------
  // Zoho Books / Zoho Finance Color Palette
  // -------------------------------------------------------------
  // Primary Zoho Colors
  static const Color zohoBlue = Color(0xFF0866FF); // Zoho Books Action Blue
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
  static const Color zohoLightBg = Color(
    0xFFF7F7F7,
  ); // Clean SaaS Light Slate Canvas
  static const Color zohoLightSurface = Color(
    0xFFFFFFFF,
  ); // Pure White Card Surface
  static const Color zohoLightSurfaceElevated = Color(
    0xFFF6F6F6,
  ); // Table Header / Subtle surface
  static const Color zohoLightBorder = Color(
    0xFFE5E5E5,
  ); // Crisp 1px card border
  static const Color zohoLightSeparator = Color(0xFFEAECF0);
  static const Color zohoLightTextPrimary = Color(
    0xFF202020,
  ); // High-contrast Charcoal Slate
  static const Color zohoLightTextSecondary = Color(
    0xFF686868,
  ); // Clean Secondary Slate
  static const Color zohoLightTextMuted = Color(0xFFAAAAAA);

  // Backward compatible aliases
  static const Color iosLightBg = zohoLightBg;
  static const Color iosLightSurface = zohoLightSurface;
  static const Color iosLightSurfaceElevated = zohoLightSurfaceElevated;
  static const Color iosLightBorder = zohoLightBorder;
  static const Color iosLightSeparator = zohoLightSeparator;
  static const Color iosLightTextPrimary = zohoLightTextPrimary;
  static const Color iosLightTextSecondary = zohoLightTextSecondary;

  // Dark Mode (Zoho Books Dark Navy)
  static const Color zohoDarkBg = Color(0xFF080808); // Deep Dark Slate Canvas
  static const Color zohoDarkSurface = Color(
    0xFF151515,
  ); // Dark Slate Card Surface
  static const Color zohoDarkSurfaceElevated = Color(0xFF1D1D1D);
  static const Color zohoDarkBorder = Color(0xFF363636);
  static const Color zohoDarkSeparator = Color(0xFF292929);
  static const Color zohoDarkTextPrimary = Color(0xFFF5F5F5);
  static const Color zohoDarkTextSecondary = Color(0xFFAAAAAA);
  static const Color zohoDarkTextMuted = Color(0xFF888888);

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
  // Compact, sharp geometry keeps finance-dense screens calm and legible.
  static const double cardRadiusVal = 14.0;
  static const double buttonRadiusVal = 8.0;
  static const double inputRadiusVal = 10.0;
  static const double badgeRadiusVal = 10.0;

  static final BorderRadius cardRadius = BorderRadius.circular(cardRadiusVal);
  static final BorderRadius buttonRadius = BorderRadius.circular(
    buttonRadiusVal,
  );
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
        width: 0.8,
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
      secondary: zohoBlue,
      onSecondary: Colors.white,
      secondaryContainer: zohoBlueBg,
      onSecondaryContainer: zohoBlueDark,
      surfaceContainerHighest: Color(0xFFF1F4F9),
      surfaceTint: Colors.transparent,
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
      textTheme: _typography(zohoLightTextPrimary),
      iconTheme: const IconThemeData(size: 20, color: zohoLightTextSecondary),
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: zohoLightSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: zohoLightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(zohoLightSurfaceElevated),
        headingTextStyle: const TextStyle(
          color: zohoLightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dataTextStyle: const TextStyle(
          color: zohoLightTextPrimary,
          fontSize: 14,
        ),
        horizontalMargin: 24,
        columnSpacing: 32,
        dividerThickness: .7,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: zohoLightSurface,
        collapsedBackgroundColor: zohoLightSurface,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: zohoLightBorder),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: zohoLightBorder),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: zohoLightBg,
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'Plus Jakarta Sans',
        '-apple-system',
        'BlinkMacSystemFont',
        'Segoe UI',
        'Roboto',
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: zohoLightSurface,
        foregroundColor: zohoLightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 64,
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusVal),
          side: const BorderSide(color: zohoLightBorder, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: zohoLightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusVal),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: zohoLightSurfaceElevated,
        side: const BorderSide(color: zohoLightBorder, width: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(badgeRadiusVal),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: zohoLightTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zohoLightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoLightBorder, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoLightBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoBlue, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoRed, width: 1.2),
        ),
        labelStyle: const TextStyle(
          color: zohoLightTextSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: zohoLightTextMuted, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: zohoBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: zohoBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: zohoLightTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: zohoLightBorder, width: 0.8),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: zohoBlue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
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
            return const TextStyle(
              color: zohoBlue,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: -0.1,
              fontFamily: 'Inter',
            );
          }
          return const TextStyle(
            color: zohoLightTextSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: zohoLightSeparator,
        thickness: 0.8,
        space: 14,
      ),
    );
  }

  // -------------------------------------------------------------
  // Theme Builder: Dark
  // -------------------------------------------------------------
  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      primary: zohoDarkTextPrimary,
      onPrimary: Colors.black,
      primaryContainer: zohoDarkSurfaceElevated,
      onPrimaryContainer: Colors.white,
      secondary: zohoDarkTextPrimary,
      onSecondary: Colors.black,
      secondaryContainer: zohoDarkSurfaceElevated,
      onSecondaryContainer: Colors.white,
      tertiary: zohoDarkTextPrimary,
      onTertiary: Colors.black,
      tertiaryContainer: zohoDarkSurfaceElevated,
      onTertiaryContainer: Colors.white,
      errorContainer: zohoDarkSurfaceElevated,
      onErrorContainer: Colors.white,
      surfaceContainerHighest: zohoDarkSurfaceElevated,
      surfaceContainerLowest: zohoDarkBg,
      surfaceContainerLow: zohoDarkSurface,
      surfaceContainer: zohoDarkSurface,
      surfaceContainerHigh: zohoDarkSurfaceElevated,
      surfaceDim: zohoDarkBg,
      surfaceBright: zohoDarkSurfaceElevated,
      inverseSurface: zohoDarkTextPrimary,
      onInverseSurface: zohoDarkBg,
      inversePrimary: zohoDarkSurfaceElevated,
      surfaceTint: Colors.transparent,
      surface: zohoDarkSurface,
      onSurface: zohoDarkTextPrimary,
      onSurfaceVariant: zohoDarkTextSecondary,
      error: zohoDarkTextPrimary,
      onError: Colors.black,
      outline: zohoDarkBorder,
      outlineVariant: zohoDarkSeparator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: _typography(zohoDarkTextPrimary),
      iconTheme: const IconThemeData(size: 20, color: zohoDarkTextSecondary),
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: zohoDarkSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: zohoDarkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(zohoDarkSurfaceElevated),
        headingTextStyle: const TextStyle(
          color: zohoDarkTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dataTextStyle: const TextStyle(
          color: zohoDarkTextPrimary,
          fontSize: 14,
        ),
        horizontalMargin: 24,
        columnSpacing: 32,
        dividerThickness: .7,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: zohoDarkSurface,
        collapsedBackgroundColor: zohoDarkSurface,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: zohoDarkBorder),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: zohoDarkBorder),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: zohoDarkBg,
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'Plus Jakarta Sans',
        '-apple-system',
        'BlinkMacSystemFont',
        'Segoe UI',
        'Roboto',
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: zohoDarkSurface,
        foregroundColor: zohoDarkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 64,
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusVal),
          side: const BorderSide(color: zohoDarkBorder, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: zohoDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadiusVal),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: zohoDarkSurfaceElevated,
        side: const BorderSide(color: zohoDarkBorder, width: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(badgeRadiusVal),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: zohoDarkTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: zohoDarkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoDarkBorder, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoDarkBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoDarkTextPrimary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadiusVal),
          borderSide: const BorderSide(color: zohoDarkTextPrimary, width: 1.2),
        ),
        labelStyle: const TextStyle(
          color: zohoDarkTextSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: zohoDarkTextMuted, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: zohoDarkTextPrimary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: zohoDarkTextPrimary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: zohoDarkTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: zohoDarkBorder, width: 0.8),
          backgroundColor: zohoDarkSurfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: zohoDarkTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadiusVal),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: zohoDarkSurface,
        elevation: 0,
        indicatorColor: zohoDarkSurfaceElevated,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: zohoDarkTextPrimary, size: 22);
          }
          return const IconThemeData(color: zohoDarkTextSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: zohoDarkTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: -0.1,
              fontFamily: 'Inter',
            );
          }
          return const TextStyle(
            color: zohoDarkTextSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: -0.1,
            fontFamily: 'Inter',
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: zohoDarkSeparator,
        thickness: 0.8,
        space: 14,
      ),
    );
  }
}

class ThemeController extends ChangeNotifier {
  static const _storageKey = 'tpc_theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_storageKey)) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _persist();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _themeMode.name);
  }
}

final themeController = ThemeController();

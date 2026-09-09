import 'package:flutter/material.dart';

class AppTheme {
  // iOS Pastel Color Palette
  static const Color pastelMint = Color(0xFF34C759); // Apple Green
  static const Color pastelMintBg = Color(0xFFE8F8F0);
  static const Color pastelMintBgDark = Color(0xFF0F2E23);

  static const Color pastelBlue = Color(0xFF007AFF); // Apple Blue
  static const Color pastelBlueBg = Color(0xFFEBF5FF);
  static const Color pastelBlueBgDark = Color(0xFF0D2A4A);

  static const Color pastelPurple = Color(0xFFAF52DE); // Apple Purple
  static const Color pastelPurpleBg = Color(0xFFF3E8FF);
  static const Color pastelPurpleBgDark = Color(0xFF28133E);

  static const Color pastelOrange = Color(0xFFFF9500); // Apple Orange
  static const Color pastelOrangeBg = Color(0xFFFFF3E6);
  static const Color pastelOrangeBgDark = Color(0xFF3B220C);

  static const Color pastelRose = Color(0xFFFF2D55); // Apple Pink/Red
  static const Color pastelRoseBg = Color(0xFFFFEAEF);
  static const Color pastelRoseBgDark = Color(0xFF38101A);

  static const Color pastelIndigo = Color(0xFF5856D6); // Apple Indigo
  static const Color pastelIndigoBg = Color(0xFFEEF0FF);
  static const Color pastelIndigoBgDark = Color(0xFF1B1B3D);

  static const Color pastelTeal = Color(0xFF30B0C7); // Apple Teal
  static const Color pastelTealBg = Color(0xFFE6F7FA);
  static const Color pastelTealBgDark = Color(0xFF0D2D35);

  // iOS System Backgrounds & Grouped Surfaces
  // Light Mode (Apple iOS 17/18 HIG)
  static const Color iosLightBg = Color(0xFFF2F2F7); // System Grouped Background
  static const Color iosLightSurface = Color(0xFFFFFFFF); // Secondary Grouped Background
  static const Color iosLightSurfaceElevated = Color(0xFFE5E5EA); // Tertiary Grouped Background
  static const Color iosLightBorder = Color(0xFFE5E5EA);
  static const Color iosLightSeparator = Color(0xFFD1D1D6);
  static const Color iosLightTextPrimary = Color(0xFF000000);
  static const Color iosLightTextSecondary = Color(0xFF8E8E93);

  // Dark Mode (Apple OLED Dark HIG)
  static const Color iosDarkBg = Color(0xFF000000); // System Grouped Background
  static const Color iosDarkSurface = Color(0xFF1C1C1E); // Secondary Grouped Background
  static const Color iosDarkSurfaceElevated = Color(0xFF2C2C2E); // Tertiary Grouped Background
  static const Color iosDarkBorder = Color(0xFF38383A);
  static const Color iosDarkSeparator = Color(0xFF38383A);
  static const Color iosDarkTextPrimary = Color(0xFFFFFFFF);
  static const Color iosDarkTextSecondary = Color(0xFF8E8E93);

  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary: pastelBlue,
      onPrimary: Colors.white,
      primaryContainer: pastelBlueBg,
      onPrimaryContainer: pastelBlue,
      secondary: pastelMint,
      onSecondary: Colors.white,
      surface: iosLightSurface,
      onSurface: iosLightTextPrimary,
      error: pastelRose,
      onError: Colors.white,
      outline: iosLightBorder,
      outlineVariant: iosLightSeparator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: iosLightBg,
      fontFamily: '-apple-system',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xDDF2F2F7),
        foregroundColor: iosLightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: iosLightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: iosLightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x15000000), width: 0.6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE3E3E8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pastelBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pastelRose, width: 1.2),
        ),
        labelStyle: const TextStyle(color: iosLightTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFFAAAAAF), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pastelBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pastelBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pastelBlue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: Color(0x30007AFF), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pastelBlue,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xE6FFFFFF),
        elevation: 0,
        indicatorColor: pastelBlueBg,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pastelBlue, size: 24);
          }
          return const IconThemeData(color: iosLightTextSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: pastelBlue, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: -0.1);
          }
          return const TextStyle(color: iosLightTextSecondary, fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: -0.1);
        }),
      ),
      dividerTheme: const DividerThemeData(color: iosLightSeparator, thickness: 0.5, space: 16),
    );
  }

  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      primary: pastelBlue,
      onPrimary: Colors.white,
      primaryContainer: pastelBlueBgDark,
      onPrimaryContainer: Colors.white,
      secondary: pastelMint,
      onSecondary: Colors.black,
      surface: iosDarkSurface,
      onSurface: iosDarkTextPrimary,
      error: pastelRose,
      onError: Colors.white,
      outline: iosDarkBorder,
      outlineVariant: iosDarkSeparator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: iosDarkBg,
      fontFamily: '-apple-system',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xDD1C1C1E),
        foregroundColor: iosDarkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: iosDarkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: iosDarkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x25FFFFFF), width: 0.6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pastelBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pastelRose, width: 1.2),
        ),
        labelStyle: const TextStyle(color: iosDarkTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF636366), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pastelBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pastelBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pastelBlue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: Color(0x50007AFF), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pastelBlue,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xE61C1C1E),
        elevation: 0,
        indicatorColor: pastelBlueBgDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pastelBlue, size: 24);
          }
          return const IconThemeData(color: iosDarkTextSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: pastelBlue, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: -0.1);
          }
          return const TextStyle(color: iosDarkTextSecondary, fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: -0.1);
        }),
      ),
      dividerTheme: const DividerThemeData(color: iosDarkSeparator, thickness: 0.5, space: 16),
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

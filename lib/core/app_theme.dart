import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFFF075AE); // Pink
  static const _secondaryColor = Color(0xFF9BC264); // Green
  static const _tertiaryColor = Color(0xFFF7DB91); // Yellow
  static const _surfaceColor = Color(0xFFFFFDCE); // Cream

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: _primaryColor,
      secondary: _secondaryColor,
      tertiary: _tertiaryColor,
      surface: _surfaceColor,
      // background is deprecated in Flutter 3.22+, mapped to surface often, but let's set it if needed or rely on surface.
      // surfaceTint: Colors.white, // Optional: if cream is too strong on appbar scroll
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // Custom App Bar "Detached"
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        titleSpacing: 16,
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        scrolledUnderElevation: 4,
        shadowColor: Colors.black12,
      ),
      // Custom FAB "Sticker Pop"
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _tertiaryColor,
        foregroundColor: Colors.black87,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        largeSizeConstraints:
            const BoxConstraints.tightFor(width: 96, height: 96),
      ),
      // Custom Dialog "Soft Card"
      dialogTheme: DialogTheme(
        backgroundColor: _surfaceColor,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
      ),
      // Custom Chips "Soft Rect"
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceColor,
        selectedColor: _secondaryColor,
        secondarySelectedColor: _secondaryColor,
        labelStyle: const TextStyle(color: Colors.black87),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        elevation: 0,
        pressElevation: 2,
      ),
      // Custom Tab Bar "Pill"
      tabBarTheme: TabBarTheme(
        indicator: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(50),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent, // Remove underline
      ),
      // Custom Dropdown Menu (M3) "Soft Pop"
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: MaterialStateProperty.all(_surfaceColor),
          surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevation: MaterialStateProperty.all(4),
        ),
      ),
      // Custom Input Decoration "Soft Pop"
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _secondaryColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: _secondaryColor.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryColor, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      // Custom Button Styling
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 2,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      // Custom Card Styling
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _primaryColor.withOpacity(0.1), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      // Keep divider theme for consistency if desired, or remove for full M3 default
      dividerTheme: const DividerThemeData(
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}

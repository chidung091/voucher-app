import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Design tokens for consistent spacing
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Design tokens for consistent corner radii
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

/// Brand palette shared by themes and themed UI components.
abstract final class AppColors {
  static const neutral = Color(0xFFEEEEEE);
  static const mint = Color(0xFF6FCF97);
  static const teal = Color(0xFF2FA084);
  static const deepTeal = Color(0xFF1F6F5F);
}

class AppTheme {
  // Dark surfaces retain contrast while using brand colors for interaction.
  static const _darkPrimaryColor = AppColors.mint;
  static const _darkSecondaryColor = AppColors.teal;
  static const _darkTertiaryColor = AppColors.deepTeal;
  static const _darkBackgroundColor = Color(0xFF0D1117); // Near-black
  static const _darkSurfaceColor = Color(0xFF161B22); // Elevated surface
  static const _darkSurfaceHighColor = Color(0xFF21262D); // Higher elevation
  static const _darkErrorColor = Color(0xFFCF6679); // Soft red

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepTeal,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.deepTeal,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mint,
      onPrimaryContainer: AppColors.deepTeal,
      secondary: AppColors.teal,
      onSecondary: Colors.black87,
      secondaryContainer: AppColors.mint,
      onSecondaryContainer: AppColors.deepTeal,
      tertiary: AppColors.mint,
      onTertiary: AppColors.deepTeal,
      surface: AppColors.neutral,
      onSurface: AppColors.deepTeal,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.neutral,
      // Custom App Bar "Detached"
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        titleSpacing: 16,
        backgroundColor: AppColors.neutral,
        foregroundColor: AppColors.deepTeal,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        scrolledUnderElevation: 4,
        shadowColor: Colors.black12,
      ),
      // Custom FAB "Sticker Pop"
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.mint,
        foregroundColor: AppColors.deepTeal,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        largeSizeConstraints:
            const BoxConstraints.tightFor(width: 96, height: 96),
      ),
      // Custom Dialog "Soft Card"
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.neutral,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.deepTeal),
      ),
      // Custom Chips "Soft Rect"
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral,
        selectedColor: AppColors.mint,
        secondarySelectedColor: AppColors.mint,
        labelStyle: const TextStyle(color: AppColors.deepTeal),
        secondaryLabelStyle: const TextStyle(color: AppColors.deepTeal),
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
          color: AppColors.deepTeal,
          borderRadius: BorderRadius.circular(50),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      // Custom Dropdown Menu (M3) "Soft Pop"
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.neutral),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevation: WidgetStateProperty.all(4),
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
          borderSide: const BorderSide(color: AppColors.teal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.teal.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.deepTeal, width: 2.5),
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
          side:
              BorderSide(color: AppColors.deepTeal.withOpacity(0.1), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      // Custom Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        height: 88,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.neutral,
        indicatorColor: AppColors.mint,
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: AppColors.deepTeal),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.neutral,
        indicatorColor: AppColors.mint,
        selectedIconTheme: const IconThemeData(color: AppColors.deepTeal),
        unselectedIconTheme:
            IconThemeData(color: AppColors.deepTeal.withOpacity(0.62)),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.deepTeal,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.deepTeal.withOpacity(0.62),
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _darkPrimaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _darkPrimaryColor,
      secondary: _darkSecondaryColor,
      tertiary: _darkTertiaryColor,
      surface: _darkSurfaceColor,
      error: _darkErrorColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.white,
      onError: Colors.black,
      surfaceContainerHighest: _darkSurfaceHighColor,
    );
    final listTileTextTheme = Typography.material2021(
      platform: defaultTargetPlatform,
    ).white;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBackgroundColor,

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        displaySmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        headlineLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        headlineSmall: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        bodySmall: TextStyle(fontSize: 12, color: Colors.white60),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        labelMedium: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
        labelSmall: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white60),
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        titleSpacing: AppSpacing.lg,
        backgroundColor: _darkSurfaceColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: Colors.black45,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkPrimaryColor,
        foregroundColor: Colors.black,
        elevation: 8,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: _darkSurfaceHighColor,
        elevation: 16,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceHighColor,
        selectedColor: _darkPrimaryColor,
        secondarySelectedColor: _darkPrimaryColor,
        labelStyle: const TextStyle(color: Colors.white70),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 2,
      ),

      // Tab Bar
      tabBarTheme: TabBarTheme(
        indicator: BoxDecoration(
          color: _darkPrimaryColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white60,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),

      // Dropdown Menu
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(_darkSurfaceHighColor),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
          elevation: WidgetStateProperty.all(8),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceHighColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white60),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: _darkPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: _darkErrorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: _darkErrorColor, width: 2),
        ),
      ),

      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkPrimaryColor,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimaryColor,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Card
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: _darkSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // List Tile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        titleTextStyle: listTileTextTheme.bodyLarge?.copyWith(
          inherit: false,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        subtitleTextStyle: listTileTextTheme.bodyMedium?.copyWith(
          inherit: false,
          fontSize: 13,
          color: Colors.white60,
        ),
      ),

      // Navigation Bar (Bottom)
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: _darkSurfaceColor,
        indicatorColor: _darkPrimaryColor.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _darkPrimaryColor);
          }
          return const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white60);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _darkPrimaryColor, size: 24);
          }
          return const IconThemeData(color: Colors.white60, size: 24);
        }),
      ),

      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _darkSurfaceColor,
        indicatorColor: _darkPrimaryColor.withOpacity(0.2),
        selectedIconTheme: const IconThemeData(color: _darkPrimaryColor),
        unselectedIconTheme: const IconThemeData(color: Colors.white60),
        selectedLabelTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _darkPrimaryColor),
        unselectedLabelTextStyle:
            const TextStyle(fontSize: 12, color: Colors.white60),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: Colors.white.withOpacity(0.08),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _darkPrimaryColor;
          return Colors.white60;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkPrimaryColor.withOpacity(0.3);
          }
          return Colors.white.withOpacity(0.1);
        }),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceHighColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: Colors.white24,
        dragHandleSize: Size(40, 4),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: Colors.white70,
        size: 24,
      ),
    );
  }
}

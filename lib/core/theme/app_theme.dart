import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme {
    final base = GoogleFonts.soraTextTheme().apply(
      bodyColor: AppColors.gray900,
      displayColor: AppColors.gray900,
    );
    return base.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        color: AppColors.gray900,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.gray900,
      ),
      bodyMedium: GoogleFonts.sora(fontSize: 14, color: AppColors.gray900),
      bodySmall: GoogleFonts.sora(fontSize: 12, color: AppColors.gray600),
      labelSmall: GoogleFonts.sora(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.gray400,
      ),
    );
  }

  static OutlineInputBorder _borde(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: ancho),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          primary: AppColors.green,
          error: AppColors.red,
          surface: Colors.white,
        ),
        textTheme: _textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.playfairDisplay(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.gray100,
            disabledForegroundColor: AppColors.gray400,
            elevation: 0,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gray900,
            side: const BorderSide(color: AppColors.gray200, width: 1.5),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.green,
            textStyle: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: GoogleFonts.sora(fontSize: 13, color: AppColors.gray400),
          labelStyle: GoogleFonts.sora(fontSize: 13, color: AppColors.gray600),
          errorStyle: GoogleFonts.sora(fontSize: 11, color: AppColors.red),
          border: _borde(AppColors.gray200),
          enabledBorder: _borde(AppColors.gray200),
          disabledBorder: _borde(AppColors.gray100),
          focusedBorder: _borde(AppColors.green, 1.5),
          errorBorder: _borde(AppColors.red, 1.5),
          focusedErrorBorder: _borde(AppColors.red, 1.5),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.gray100),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.gray100,
          thickness: 1,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.green,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.gray900,
          contentTextStyle: GoogleFonts.sora(fontSize: 13, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}

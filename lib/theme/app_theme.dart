import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PRONO4 — identité premium sports-tech.
/// Noir profond + blanc cassé + vert victoire électrique.
class AppColors {
  static const bg0 = Color(0xFF101211);
  static const bg1 = Color(0xFF141816);
  static const bg2 = Color(0xFF191E1B);
  static const bg3 = Color(0xFF202722);

  static const lime = Color(0xFFB6FF3B);
  static const limeSoft = Color(0xFFD8FF95);
  static const limeDark = Color(0xFF76B900);

  // Aliases conservés pour ne pas casser les anciens écrans.
  static const gold = lime;
  static const gold2 = Color(0xFF8FEA14);
  static const goldLt = limeSoft;
  static const mexicoGreen = lime;
  static const mexicoGreenDk = limeDark;
  static const usaBlue = Color(0xFF94A8FF);
  static const usaBlueDk = Color(0xFF6C7ED6);
  static const canadaRed = Color(0xFFFF5C68);
  static const canadaRedDk = Color(0xFFD74350);
  static const cyan = Color(0xFF8CE9D3);
  static const violet = Color(0xFFC7A6FF);
  static const magenta = Color(0xFFFF86C8);

  static const blue = usaBlue;
  static const green = lime;
  static const red = canadaRed;

  static const text = Color(0xFFF7F8F5);
  static const text2 = Color(0xFFC9CEC8);
  static const grey = Color(0xFF838B85);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF171C18), Color(0xFF101211), Color(0xFF152014)],
  );

  static const trophyGradient = LinearGradient(
    colors: [limeSoft, lime, Color(0xFF83DD11)],
  );

  static const tripleHostGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFF7F8F5), lime, Color(0xFF8CE9D3)],
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg0,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.lime,
          onPrimary: AppColors.bg0,
          secondary: AppColors.lime,
          tertiary: AppColors.cyan,
          surface: AppColors.bg2,
          error: AppColors.canadaRed,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontWeight: FontWeight.w800),
          displayMedium: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontWeight: FontWeight.w800),
          displaySmall: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontWeight: FontWeight.w800),
          headlineLarge: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontWeight: FontWeight.w800),
          headlineMedium: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontWeight: FontWeight.w800),
          headlineSmall: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontWeight: FontWeight.w800),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.spaceGrotesk(
            color: AppColors.text,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.bg1,
          selectedItemColor: AppColors.lime,
          unselectedItemColor: AppColors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.bg2,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(.07)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bg3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: AppColors.lime, width: 1.5),
          ),
          hintStyle: const TextStyle(color: AppColors.grey),
          labelStyle: const TextStyle(color: AppColors.text2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lime,
            foregroundColor: AppColors.bg0,
            textStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lime,
            foregroundColor: AppColors.bg0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: BorderSide(color: Colors.white.withOpacity(.14)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bg2,
          selectedColor: AppColors.lime.withOpacity(.14),
          side: BorderSide(color: Colors.white.withOpacity(.07)),
          labelStyle: GoogleFonts.inter(color: AppColors.text2, fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        dividerColor: Colors.white.withOpacity(.06),
        splashFactory: InkRipple.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }),
      );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PRONO4 — identité premium sports-tech.
/// Le vert électrique reste la signature de marque, avec deux palettes :
/// sombre premium et claire premium.
class AppColors {
  static bool _lightMode = false;
  static bool get isLight => _lightMode;
  static set lightMode(bool value) => _lightMode = value;

  static Color get bg0 => _lightMode ? const Color(0xFFF4F6F1) : const Color(0xFF101211);
  static Color get bg1 => _lightMode ? const Color(0xFFFFFFFF) : const Color(0xFF141816);
  static Color get bg2 => _lightMode ? const Color(0xFFFFFFFF) : const Color(0xFF191E1B);
  static Color get bg3 => _lightMode ? const Color(0xFFE9EEE6) : const Color(0xFF202722);

  static const lime = Color(0xFF32C653);
  static const limeSoft = Color(0xFF8BE29C);
  static const limeDark = Color(0xFF16843A);

  // Aliases conservés pour ne pas casser les anciens écrans.
  static const gold = lime;
  static const gold2 = Color(0xFF27B84A);
  static const goldLt = limeSoft;
  static const mexicoGreen = lime;
  static const mexicoGreenDk = limeDark;
  static const usaBlue = Color(0xFF6678D8);
  static const usaBlueDk = Color(0xFF5363BA);
  static const canadaRed = Color(0xFFE34D59);
  static const canadaRedDk = Color(0xFFC23A46);
  static const cyan = Color(0xFF45BDA5);
  static const violet = Color(0xFF9A73D9);
  static const magenta = Color(0xFFE85EAC);

  static const blue = usaBlue;
  static const green = lime;
  static const red = canadaRed;

  static Color get text => _lightMode ? const Color(0xFF151915) : const Color(0xFFF7F8F5);
  static Color get text2 => _lightMode ? const Color(0xFF4F5A51) : const Color(0xFFC9CEC8);
  static Color get grey => _lightMode ? const Color(0xFF717A72) : const Color(0xFF838B85);
  static Color get overlayBase => _lightMode ? Colors.black : Colors.white;
  static Color get ringNeutral => _lightMode ? Colors.black26 : Colors.white24;
  static Color get logoPlate => _lightMode ? const Color(0xFFE8EDE8) : const Color(0xFF111713);
  static Color get logoPlateBorder => _lightMode ? const Color(0x22000000) : const Color(0x22FFFFFF);
  static Color get shadow => _lightMode ? Colors.black.withOpacity(.12) : Colors.black.withOpacity(.34);

  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _lightMode
        ? const [Color(0xFFFFFFFF), Color(0xFFF4F6F1), Color(0xFFEAF3DF)]
        : const [Color(0xFF171C18), Color(0xFF101211), Color(0xFF152014)],
  );

  static const trophyGradient = LinearGradient(
    colors: [limeSoft, lime, Color(0xFF27B84A)],
  );

  static LinearGradient get tripleHostGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: _lightMode
        ? const [Color(0xFF151915), Color(0xFF5E9400), Color(0xFF258D78)]
        : const [Color(0xFFF7F8F5), lime, Color(0xFF8CE9D3)],
  );
}

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get theme => darkTheme;

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final bg0 = light ? const Color(0xFFF4F6F1) : const Color(0xFF101211);
    final bg1 = light ? const Color(0xFFFFFFFF) : const Color(0xFF141816);
    final bg2 = light ? const Color(0xFFFFFFFF) : const Color(0xFF191E1B);
    final bg3 = light ? const Color(0xFFE9EEE6) : const Color(0xFF202722);
    final text = light ? const Color(0xFF151915) : const Color(0xFFF7F8F5);
    final text2 = light ? const Color(0xFF4F5A51) : const Color(0xFFC9CEC8);
    final grey = light ? const Color(0xFF717A72) : const Color(0xFF838B85);
    final primary = light ? AppColors.limeDark : AppColors.lime;
    final border = light ? Colors.black.withOpacity(.08) : Colors.white.withOpacity(.07);

    final baseText = light ? ThemeData.light().textTheme : ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg0,
      colorScheme: light
          ? ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              secondary: AppColors.limeDark,
              tertiary: AppColors.cyan,
              surface: bg2,
              onSurface: text,
              error: AppColors.canadaRed,
            )
          : const ColorScheme.dark(
              primary: AppColors.lime,
              onPrimary: Color(0xFF101211),
              secondary: AppColors.lime,
              tertiary: AppColors.cyan,
              surface: Color(0xFF191E1B),
              error: AppColors.canadaRed,
            ),
      textTheme: GoogleFonts.interTextTheme(baseText).apply(
        bodyColor: text,
        displayColor: text,
      ).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(color: text, fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.spaceGrotesk(color: text, fontWeight: FontWeight.w800),
        displaySmall: GoogleFonts.spaceGrotesk(color: text, fontWeight: FontWeight.w800),
        headlineLarge: GoogleFonts.spaceGrotesk(color: text, fontWeight: FontWeight.w800),
        headlineMedium: GoogleFonts.spaceGrotesk(color: text, fontWeight: FontWeight.w800),
        headlineSmall: GoogleFonts.spaceGrotesk(color: text, fontWeight: FontWeight.w800),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: text,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg1,
        selectedItemColor: primary,
        unselectedItemColor: grey,
        type: BottomNavigationBarType.fixed,
        elevation: light ? 7 : 0,
      ),
      cardTheme: CardThemeData(
        color: bg2,
        elevation: light ? 1 : 0,
        shadowColor: Colors.black.withOpacity(.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: grey),
        labelStyle: TextStyle(color: text2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: light ? Colors.white : const Color(0xFF101211),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: light ? Colors.white : const Color(0xFF101211),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: light ? Colors.black.withOpacity(.14) : Colors.white.withOpacity(.14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bg2,
        selectedColor: primary.withOpacity(.14),
        side: BorderSide(color: border),
        labelStyle: GoogleFonts.inter(color: text2, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerColor: light ? Colors.black.withOpacity(.07) : Colors.white.withOpacity(.06),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

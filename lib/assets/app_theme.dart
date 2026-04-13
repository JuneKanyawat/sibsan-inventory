import 'package:flutter/material.dart';

// Bar text /
// big month text /
// very big price text bold/
// big number home
// small text //
// default text 16//
// default text but bold//

// Regular < Medium < Semi Bold < Bold
TextTheme _asthaTutorialTextTheme(TextTheme base) => base.copyWith(
  // for appbars title
  titleLarge: base.titleLarge!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.w600,
    fontSize: 20,
    color: const Color(0xFF000000),
  ),

  // for very big total text
  displayLarge: base.displayLarge!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.bold,
    fontSize: 36,
    color: const Color(0xFF000000),
  ),

  // for big month text
  headlineLarge: base.headlineLarge!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.w500,
    fontSize: 24,
    color: const Color(0xFF000000),
  ),

  // for card number home page
  headlineMedium: base.headlineMedium!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.w600,
    fontSize: 24,
    color: const Color(0xFF000000),
  ),

  // for default text
  bodyMedium: base.bodyMedium!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: const Color(0xFF000000),
  ),

  // for default text but bold
  titleMedium: base.titleMedium!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: const Color(0xFF000000),
  ),

  // for card sub title (small text)
  bodySmall: base.bodySmall!.copyWith(
    fontFamily: "Quicksand",
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: const Color(0xFF9E9E9E), // Sub text color
  ),
);

final ThemeData appTheme = ThemeData(
  fontFamily: 'Quicksand',
  brightness: Brightness.light,
  primaryColor: const Color(0xFFFFF9C4),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFFFF9C4),
    foregroundColor: const Color(0xFF000000),
    titleTextStyle: _asthaTutorialTextTheme(
      ThemeData.light().textTheme,
    ).titleLarge,
    elevation: 0,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    selectedItemColor: Color(0xFF000000),
    unselectedItemColor: Color(0xFF9E9E9E),
    showSelectedLabels: false,
    showUnselectedLabels: false,
  ),
  textTheme: _asthaTutorialTextTheme(ThemeData.light().textTheme),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFFFF9C4),
    secondary: Color(0xFFE62314),
    error: Color(0xFFE62314), // Red color
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
  ),
);

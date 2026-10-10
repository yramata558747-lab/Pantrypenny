
import 'package:flutter/material.dart';

class PantryStyle {
  PantryStyle._();

  static const primary = Color(0xFF397A5B);
  static const primaryDark = Color(0xFF245C48);
  static const accent = Color(0xFFD89A4A);
  static const danger = Color(0xFFC56860);

  static const ink = Color(0xFF243C30);
  static const inkSoft = Color(0xFF708076);
  static const surface = Color(0xFFF7F8F6);
  static const cardBorder = Color(0xFFE5EBE6);
  static const actionBlue = Color(0xFF3270B0);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF245C48),
      Color(0xFF397A5B),
    ],
  );

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primaryDark,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: inkSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: cardBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: cardBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primaryDark,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(
            color: cardBorder,
          ),
        ),
      ),
    );
  }
}

class CategoryStyle {
  final IconData icon;
  final Color color;

  const CategoryStyle(this.icon, this.color);

  static const _map = <String, CategoryStyle>{
    'Dairy': CategoryStyle(
      Icons.local_drink_outlined,
      Color(0xFF6385A0),
    ),
    'Produce': CategoryStyle(
      Icons.eco_outlined,
      Color(0xFF397A5B),
    ),
    'Vegetables': CategoryStyle(
      Icons.eco_outlined,
      Color(0xFF397A5B),
    ),
    'Fruits': CategoryStyle(
      Icons.spa_outlined,
      Color(0xFF9A7857),
    ),
    'Dry Goods': CategoryStyle(
      Icons.rice_bowl_outlined,
      Color(0xFF9A7857),
    ),
    'Grains': CategoryStyle(
      Icons.rice_bowl_outlined,
      Color(0xFF9A7857),
    ),
    'Meat & Seafood': CategoryStyle(
      Icons.restaurant_outlined,
      Color(0xFFBD746C),
    ),
    'Other': CategoryStyle(
      Icons.inventory_2_outlined,
      Color(0xFF74827B),
    ),
  };

  static CategoryStyle of(String category) {
    return _map[category] ?? _map['Other']!;
  }
}

class LocationStyle {
  final IconData icon;

  const LocationStyle(this.icon);

  static const _map = <String, LocationStyle>{
    'Fridge': LocationStyle(
      Icons.kitchen_outlined,
    ),
    'Freezer': LocationStyle(
      Icons.ac_unit_outlined,
    ),
    'Pantry': LocationStyle(
      Icons.inventory_2_outlined,
    ),
  };

  static LocationStyle of(String location) {
    return _map[location] ??
        const LocationStyle(
          Icons.inventory_2_outlined,
        );
  }
}

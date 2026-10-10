// Basic smoke test — confirms the app builds and the Pantry Inventory
// screen title shows up.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pantrypenny/models/pantry_item.dart';
import 'package:pantrypenny/models/pantry_provider.dart';
import 'package:pantrypenny/main.dart';

void main() {
  testWidgets('PantryPenny app builds and shows the Pantry Inventory title',
      (WidgetTester tester) async {
    Hive.init('./.dart_tool/hive_test');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PantryItemAdapter());
    }
    final pantryProvider = PantryProvider();
    await pantryProvider.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: pantryProvider,
        child: const PantryPennyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Pantry 🧺'), findsOneWidget);
  });
}
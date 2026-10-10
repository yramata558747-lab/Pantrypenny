import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'restock_item.dart';

class RestockProvider extends ChangeNotifier {
  static const String _boxName = 'restock_items';
  static const String _metaBoxName = 'restock_meta';

  late Box<RestockItem> _box;
  late Box _metaBox;

  // ============================================================
  // INITIALIZE HIVE
  // ============================================================

  Future<void> init() async {
    _box = await Hive.openBox<RestockItem>(_boxName);
    _metaBox = await Hive.openBox(_metaBoxName);
    notifyListeners();
  }

  // ============================================================
  // GO GROCERY
  // ============================================================

  List<RestockItem> get pending {
    final list =
        _box.values.where((item) => !item.bought).toList();

    list.sort(
      (a, b) => b.dateAdded.compareTo(a.dateAdded),
    );

    return list;
  }

  // ============================================================
  // PURCHASE HISTORY
  // ============================================================

  List<RestockItem> get history {
    final list =
        _box.values.where((item) => item.bought).toList();

    list.sort((a, b) {
      final first = a.datePurchased ?? a.dateAdded;
      final second = b.datePurchased ?? b.dateAdded;
      return second.compareTo(first);
    });

    return list;
  }

  // ============================================================
  // BUDGET
  // Spending only counts PURCHASED items (Purchase History),
  // never items that are merely on the shopping list.
  // ============================================================

  double get totalPendingCost {
    return pending.fold<double>(
      0.0,
      (sum, item) => sum + item.estimatedPrice,
    );
  }

  double get spentThisMonth {
    final now = DateTime.now();

    return history.where((item) {
      final date = item.datePurchased;

      return date != null &&
          date.year == now.year &&
          date.month == now.month;
    }).fold<double>(
      0.0,
      (sum, item) => sum + item.estimatedPrice,
    );
  }

  double get monthlyBudget {
    final value = _metaBox.get(
      'monthlyBudget',
      defaultValue: 0.0,
    );

    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  double get remainingBudget => monthlyBudget - spentThisMonth;

  Future<void> setMonthlyBudget(double value) async {
    if (!value.isFinite || value < 0) {
      throw ArgumentError('Invalid grocery budget.');
    }

    await _metaBox.put('monthlyBudget', value);
    notifyListeners();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isPendingName(String name) {
    final key = name.trim().toLowerCase();

    return _box.values.any(
      (item) =>
          !item.bought &&
          item.name.trim().toLowerCase() == key,
    );
  }

  /// Make sure the item is a live record in the Hive box.
  void _ensureSaved(RestockItem item) {
    if (!item.isInBox) {
      throw StateError(
        'This grocery item is no longer saved.',
      );
    }

    if (!_box.containsKey(item.key)) {
      throw StateError(
        'This grocery item could not be found.',
      );
    }
  }

  void _validatePackage({
    required int count,
    required double size,
    required double totalPrice,
  }) {
    if (count <= 0 ||
        size <= 0 ||
        !size.isFinite ||
        totalPrice < 0 ||
        !totalPrice.isFinite) {
      throw ArgumentError(
        'Please enter valid package details.',
      );
    }
  }

  // ============================================================
  // ADD ITEM TO GO GROCERY (quick add, minimal details)
  // Kept for existing callers.
  // ============================================================

  Future<void> addToRestock({
    required String name,
    required String category,
    String unit = 'pcs',
    String location = 'Pantry',
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) return;
    if (_isPendingName(cleanName)) return;

    await _box.add(
      RestockItem(
        name: cleanName,
        category: category,
        unit: unit,
        location: location,
        estimatedPrice: 0,
        dateAdded: DateTime.now(),
        bought: false,
      ),
    );

    notifyListeners();
  }

  // ============================================================
  // ADD ITEM WITH FULL PACKAGE DETAILS (single save)
  // 4 packs x 1 kg at P250 each -> total P1,000 saved directly.
  // ============================================================

  Future<void> addGrocery({
    required String name,
    String category = 'Other',
    required int count,
    required double size,
    required String packageType,
    required String unit,
    required String location,
    required double totalPrice,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Please enter an item name.');
    }

    _validatePackage(
      count: count,
      size: size,
      totalPrice: totalPrice,
    );

    if (_isPendingName(cleanName)) {
      throw StateError(
        'This item is already in your grocery list.',
      );
    }

    await _box.add(
      RestockItem(
        name: cleanName,
        category: category,
        unit: unit,
        location: location,
        estimatedPrice: totalPrice,
        dateAdded: DateTime.now(),
        bought: false,
        packageCount: count,
        packageType: packageType,
        packageSize: size,
        unitPrice: totalPrice / count,
      ),
    );

    notifyListeners();
  }

  // ============================================================
  // EDIT PACKAGE DETAILS
  // ============================================================

  Future<void> configurePackage(
    RestockItem item, {
    required int count,
    required double size,
    required String packageType,
    required String unit,
    required String location,
    required double totalPrice,
  }) async {
    _ensureSaved(item);

    if (item.bought) {
      throw StateError(
        'This item has already been purchased.',
      );
    }

    _validatePackage(
      count: count,
      size: size,
      totalPrice: totalPrice,
    );

    item.packageCount = count;
    item.packageSize = size;
    item.packageType = packageType;
    item.unit = unit;
    item.location = location;
    item.estimatedPrice = totalPrice;
    item.unitPrice = totalPrice / count;

    await item.save();
    notifyListeners();
  }

  // ============================================================
  // UPDATE GROCERY PRICE
  // ============================================================

  Future<void> updatePrice(
    RestockItem item,
    double price,
  ) async {
    _ensureSaved(item);

    if (price < 0 || !price.isFinite) {
      throw ArgumentError('Invalid grocery price.');
    }

    item.estimatedPrice = price;

    final count =
        item.packageCount > 0 ? item.packageCount : 1;

    item.unitPrice = price / count;

    await item.save();
    notifyListeners();
  }

  // ============================================================
  // COMPLETE A PURCHASE
  // Saves the final package details AND marks the item as bought
  // in ONE write, so the record can never end up half-updated.
  // ============================================================

  Future<void> completePurchase(
    RestockItem item, {
    required int count,
    required double size,
    required String packageType,
    required String unit,
    required String location,
    required double totalPrice,
    required DateTime purchaseDate,
  }) async {
    _ensureSaved(item);

    if (item.bought) {
      throw StateError(
        'This grocery item is already purchased.',
      );
    }

    _validatePackage(
      count: count,
      size: size,
      totalPrice: totalPrice,
    );

    // Snapshot for rollback if Hive fails to write.
    final old = (
      count: item.packageCount,
      size: item.packageSize,
      type: item.packageType,
      unit: item.unit,
      location: item.location,
      total: item.estimatedPrice,
      each: item.unitPrice,
    );

    item.packageCount = count;
    item.packageSize = size;
    item.packageType = packageType;
    item.unit = unit;
    item.location = location;
    item.estimatedPrice = totalPrice;
    item.unitPrice = totalPrice / count;
    item.bought = true;
    item.datePurchased = purchaseDate;

    try {
      await item.save();
    } catch (_) {
      item.packageCount = old.count;
      item.packageSize = old.size;
      item.packageType = old.type;
      item.unit = old.unit;
      item.location = old.location;
      item.estimatedPrice = old.total;
      item.unitPrice = old.each;
      item.bought = false;
      item.datePurchased = null;
      rethrow;
    }

    notifyListeners();
  }

  // ============================================================
  // MARK GROCERY AS PURCHASED (kept for compatibility)
  // ============================================================

  Future<void> markBought(
    RestockItem item, {
    DateTime? purchaseDate,
  }) async {
    _ensureSaved(item);

    if (item.bought) {
      throw StateError(
        'This grocery item is already purchased.',
      );
    }

    item.bought = true;
    item.datePurchased = purchaseDate ?? DateTime.now();

    try {
      await item.save();
    } catch (_) {
      item.bought = false;
      item.datePurchased = null;
      rethrow;
    }

    notifyListeners();
  }

  // ============================================================
  // UNDO A PURCHASE
  // Used only if adding the stock to My Pantry fails, so the item
  // returns to Go Grocery instead of being lost.
  // ============================================================

  Future<void> undoPurchase(RestockItem item) async {
    if (!item.isInBox) return;

    item.bought = false;
    item.datePurchased = null;

    await item.save();
    notifyListeners();
  }

  // ============================================================
  // BUY AGAIN FROM USAGE HISTORY
  // Preserve saved quantity, package size and price.
  // ============================================================

  Future<void> buyAgain(
    Map<String, dynamic> record,
  ) async {
    String readText(String key, String fallback) {
      final value = record[key]?.toString().trim();
      return value == null || value.isEmpty
          ? fallback
          : value;
    }

    double readNumber(String key) {
      final value = record[key];

      if (value is num) return value.toDouble();

      if (value is String) {
        return double.tryParse(value.trim()) ?? 0;
      }

      return 0;
    }

    final name = readText('name', '');

    if (name.isEmpty) return;

    final category = readText('category', 'Other');
    final unit = readText('unit', 'pcs');
    final location = readText('location', 'Pantry');
    final packageType = readText('packageType', 'pack');

    final recordedCount = readNumber('packageCount');
    final count =
        recordedCount.isFinite && recordedCount >= 1
            ? recordedCount.toInt()
            : 1;

    final recordedSize = readNumber('packageSize');
    final amount = readNumber('amount');

    final size = recordedSize > 0 && recordedSize.isFinite
        ? recordedSize
        : amount > 0 && amount.isFinite
            ? amount / count
            : 1.0;

    final recordedTotal = readNumber('totalPrice');
    final recordedEach = readNumber('pricePerPackage');

    final totalPrice =
        recordedTotal > 0 && recordedTotal.isFinite
            ? recordedTotal
            : recordedEach > 0 && recordedEach.isFinite
                ? recordedEach * count
                : 0.0;

    RestockItem? existing;

    for (final item in _box.values) {
      if (!item.bought &&
          item.name.trim().toLowerCase() ==
              name.toLowerCase()) {
        existing = item;
        break;
      }
    }

    if (existing != null) {
      existing.category = category;
      existing.unit = unit;
      existing.location = location;
      existing.packageCount = count;
      existing.packageSize = size;
      existing.packageType = packageType;
      existing.estimatedPrice = totalPrice;
      existing.unitPrice = totalPrice / count;

      await existing.save();
    } else {
      await _box.add(
        RestockItem(
          name: name,
          category: category,
          unit: unit,
          location: location,
          estimatedPrice: totalPrice,
          dateAdded: DateTime.now(),
          bought: false,
          packageCount: count,
          packageSize: size,
          packageType: packageType,
          unitPrice: totalPrice / count,
        ),
      );
    }

    notifyListeners();
  }

  // ============================================================
  // REMOVE GROCERY ITEM
  // ============================================================

  Future<void> removeFromRestock(
    RestockItem item,
  ) async {
    _ensureSaved(item);

    await item.delete();
    notifyListeners();
  }

  // ============================================================
  // CLEAR ALL
  // Only call after user confirms account/data deletion.
  // ============================================================

  Future<void> clearAll() async {
    await _box.clear();
    await _metaBox.clear();
    notifyListeners();
  }
}
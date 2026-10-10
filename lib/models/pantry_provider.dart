import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/crud_service.dart';
import 'pantry_item.dart';

class PantryProvider extends ChangeNotifier {
  static const String _boxName = 'pantry_items';
  static const String _historyBoxName =
      'pantry_usage_history';

  late Box<PantryItem> _box;
  late Box _usageBox;

  // Firestore mirror (Create / Update / Delete).
  final CrudService _cloud;

  PantryProvider({CrudService? cloud})
      : _cloud = cloud ?? CrudService();

  // ---- CLOUD MIRROR HELPERS ----------------------------------
  // Hive stays the source of truth. Every change is also sent to
  // Firestore in the background; failures never block the app.

  String _newCloudId() {
    final random = Random().nextInt(1 << 31);
    return '${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  Future<void> _push(PantryItem item) async {
    try {
      if (!_cloud.isSignedIn) return;

      if (item.cloudId.isEmpty) {
        item.cloudId = _newCloudId();
        if (item.isInBox) await item.save();
      }

      unawaited(
        _cloud.upsertItem(item).catchError((Object _) {}),
      );
    } catch (_) {
      // Cloud sync is best-effort.
    }
  }

  void _cloudDelete(String cloudId) {
    if (cloudId.isEmpty || !_cloud.isSignedIn) return;

    unawaited(
      _cloud.deleteItem(cloudId).catchError((Object _) {}),
    );
  }

  /// Upload every local pantry item to Firestore.
  /// Runs after login so existing Hive data is preserved and
  /// available in the cloud.
  Future<void> syncAllToCloud() async {
    if (!_cloud.isSignedIn) return;

    for (final item in _box.values.toList()) {
      await _push(item);
    }
  }

  Future<void> init() async {
    _box = await Hive.openBox<PantryItem>(_boxName);
    _usageBox = await Hive.openBox(_historyBoxName);
    notifyListeners();
  }

  // MY PANTRY

  List<PantryItem> get items {
    final all = _box.values.toList();

    all.sort(
      (a, b) => b.purchaseDate.compareTo(a.purchaseDate),
    );

    return all;
  }

  // USAGE HISTORY

  List<Map<String, dynamic>> get usageHistory {
    final records = _usageBox.values.map((value) {
      return Map<String, dynamic>.from(value as Map);
    }).toList();

    records.sort((a, b) {
      final first = a['usedAt']?.toString() ?? '';
      final second = b['usedAt']?.toString() ?? '';
      return second.compareTo(first);
    });

    return records;
  }

  // ADD ITEM MANUALLY

  Future<void> addItem(PantryItem item) async {
    if (item.name.trim().isEmpty ||
        item.amount <= 0 ||
        !item.amount.isFinite) {
      return;
    }

    if (item.cloudId.isEmpty) item.cloudId = _newCloudId();

    await _box.add(item);
    notifyListeners();

    unawaited(_push(item));
  }

  // EDIT AN EXISTING ITEM (Update)

  Future<void> updateItem(
    PantryItem item,
    PantryItem edited,
  ) async {
    if (!item.isInBox) {
      throw StateError('This pantry item is no longer saved.');
    }

    if (edited.name.trim().isEmpty ||
        edited.amount <= 0 ||
        !edited.amount.isFinite ||
        edited.packageSize <= 0) {
      throw ArgumentError('Invalid pantry item.');
    }

    final sameStock =
        edited.packageCount == item.packageCount &&
            edited.packageSize == item.packageSize;

    item.name = edited.name.trim();
    item.unit = edited.unit;
    item.location = edited.location;
    item.purchaseDate = edited.purchaseDate;
    item.packageType = edited.packageType;
    item.packageCount = edited.packageCount;
    item.packageSize = edited.packageSize;
    item.imageUrl = edited.imageUrl;

    // Keep a partly-used remaining amount unless the user
    // actually changed the package count or size.
    if (!sameStock) {
      item.amount = edited.amount;
    }

    item.totalPrice =
        item.pricePerPackage * item.packageCount;

    await item.save();
    notifyListeners();

    unawaited(_push(item));
  }

  // ADD PURCHASED GROCERY TO MY PANTRY

  Future<void> addPurchasedItem({
    required String name,
    required double amount,
    required String unit,
    required String category,
    required String location,
    required DateTime purchaseDate,
    int packageCount = 1,
    double packageSize = 0,
    String packageType = 'pack',
    double pricePerPackage = 0,
    double totalPrice = 0,
  }) async {
    if (name.trim().isEmpty ||
        amount <= 0 ||
        !amount.isFinite) {
      throw ArgumentError('Invalid pantry item.');
    }

    final safeCount =
        packageCount > 0 ? packageCount : 1;

    final safeSize = packageSize > 0
        ? packageSize
        : amount / safeCount;

    if (!safeSize.isFinite || safeSize <= 0) {
      throw ArgumentError('Invalid package size.');
    }

    final safeTotalPrice = totalPrice > 0
        ? totalPrice
        : pricePerPackage * safeCount;

    final safePricePerPackage =
        pricePerPackage > 0
            ? pricePerPackage
            : safeTotalPrice / safeCount;

    final newItem = PantryItem(
      name: name.trim(),
      amount: safeCount * safeSize,
      unit: unit,
      category: category,
      location: location,
      purchaseDate: purchaseDate,
      packageCount: safeCount,
      packageSize: safeSize,
      packageType: packageType,
      pricePerPackage: safePricePerPackage,
      totalPrice: safeTotalPrice,
      cloudId: _newCloudId(),
    );

    await _box.add(newItem);
    notifyListeners();

    unawaited(_push(newItem));
  }

  // REMOVE PANTRY ITEM

  Future<void> removeItem(PantryItem item) async {
    if (!item.isInBox) return;

    final cloudId = item.cloudId;

    await item.delete();
    notifyListeners();

    _cloudDelete(cloudId);
  }

  // USE A SPECIFIC NUMBER OF PACKAGES

  Future<void> usePackages(
    PantryItem item,
    int count,
  ) async {
    if (!item.isInBox ||
        count <= 0 ||
        item.amount <= 0 ||
        item.packageSize <= 0) {
      return;
    }

    final available = item.fullPackagesRemaining;

    if (available <= 0) return;

    final actualCount =
        count > available ? available : count;

    final amountUsed =
        actualCount * item.packageSize;

    final remaining = (item.amount - amountUsed)
        .clamp(0.0, double.infinity)
        .toDouble();

    final record = <String, dynamic>{
      'name': item.name,
      'amount': amountUsed,
      'unit': item.unit,
      'category': item.category,
      'location': item.location,
      'packageCount': actualCount,
      'originalPackageCount': item.packageCount,
      'packageSize': item.packageSize,
      'packageType': item.packageType,
      'pricePerPackage': item.pricePerPackage,
      'totalPrice':
          item.pricePerPackage * actualCount,
      'purchaseDate':
          item.purchaseDate.toIso8601String(),
      'usedAt': DateTime.now().toIso8601String(),
    };

    // Save history before changing stock.
    await _usageBox.add(record);

    final cloudId = item.cloudId;

    if (remaining <= 0.000001) {
      await item.delete();
      _cloudDelete(cloudId);
    } else {
      item.amount = remaining;
      item.packageCount =
          item.fullPackagesRemaining;

      await item.save();
      unawaited(_push(item));
    }

    notifyListeners();
  }

  // USE ALL PACKAGES

  Future<void> useAll(PantryItem item) async {
    if (!item.isInBox || item.amount <= 0) return;

    final amountUsed = item.amount;

    final count = item.packageSize > 0
        ? item.fullPackagesRemaining
        : item.packageCount;

    final record = <String, dynamic>{
      'name': item.name,
      'amount': amountUsed,
      'unit': item.unit,
      'category': item.category,
      'location': item.location,
      'packageCount': count,
      'originalPackageCount': item.packageCount,
      'packageSize': item.packageSize,
      'packageType': item.packageType,
      'pricePerPackage': item.pricePerPackage,
      'totalPrice':
          item.pricePerPackage * count,
      'purchaseDate':
          item.purchaseDate.toIso8601String(),
      'usedAt': DateTime.now().toIso8601String(),
    };

    await _usageBox.add(record);

    final cloudId = item.cloudId;

    await item.delete();
    notifyListeners();

    _cloudDelete(cloudId);
  }

  // LEGACY AMOUNT-BASED USAGE

  Future<void> useAmount(
    PantryItem item,
    double amountUsed,
  ) async {
    if (!item.isInBox ||
        amountUsed <= 0 ||
        !amountUsed.isFinite) {
      return;
    }

    final actualUsed =
        amountUsed > item.amount
            ? item.amount
            : amountUsed;

    final remaining = (item.amount - actualUsed)
        .clamp(0.0, double.infinity)
        .toDouble();

    final size = item.packageSize;

    final packagesUsed =
        size > 0 ? actualUsed / size : 0.0;

    final record = <String, dynamic>{
      'name': item.name,
      'amount': actualUsed,
      'unit': item.unit,
      'category': item.category,
      'location': item.location,
      'originalPackageCount': item.packageCount,
      'packageCount':
          packagesUsed == packagesUsed.roundToDouble()
              ? packagesUsed.toInt()
              : 0,
      'packageSize': item.packageSize,
      'packageType': item.packageType,
      'pricePerPackage': item.pricePerPackage,
      'totalPrice':
          packagesUsed * item.pricePerPackage,
      'purchaseDate':
          item.purchaseDate.toIso8601String(),
      'usedAt': DateTime.now().toIso8601String(),
    };

    await _usageBox.add(record);

    final cloudId = item.cloudId;

    if (remaining <= 0.000001) {
      await item.delete();
      _cloudDelete(cloudId);
    } else {
      item.amount = remaining;

      if (size > 0) {
        item.packageCount =
            item.fullPackagesRemaining;
      }

      await item.save();
      unawaited(_push(item));
    }

    notifyListeners();
  }

  // DELETE DATA ONLY AFTER USER CONFIRMATION

  Future<void> clearAll() async {
    // Remove the cloud copies first (needs the signed-in user).
    // A timeout keeps this from hanging while offline.
    try {
      await _cloud
          .deleteAllItems()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}

    await _box.clear();
    await _usageBox.clear();
    notifyListeners();
  }
}
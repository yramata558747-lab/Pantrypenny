import 'package:hive/hive.dart';

part 'restock_item.g.dart';

@HiveType(typeId: 1)
class RestockItem extends HiveObject {
  // ============================================================
  // HIVE FIELDS
  // Keep these IDs unchanged for existing saved data.
  //
  // NOTE: This class must NOT declare its own `isInBox`.
  // HiveObject already provides `isInBox`. Declaring a field with
  // the same name replaced Hive's version, was never saved, and was
  // always `false` - which is why Mark Purchased, Edit and Remove
  // reported that the item was "no longer saved".
  // ============================================================

  @HiveField(0)
  String name;

  @HiveField(1)
  String category;

  @HiveField(2)
  String unit;

  @HiveField(3)
  String location;

  // Total price of this grocery entry (all packages).
  @HiveField(4)
  double estimatedPrice;

  @HiveField(5)
  DateTime dateAdded;

  // False = Go Grocery, True = Purchase History
  @HiveField(6)
  bool bought;

  @HiveField(7)
  DateTime? datePurchased;

  // Number of packages to buy / already purchased.
  @HiveField(8)
  int packageCount;

  // pack, pouch, bottle, bag, sack, etc.
  @HiveField(9)
  String packageType;

  // Size of ONE package (example: 1 kg).
  @HiveField(10)
  double packageSize;

  // Price of ONE package.
  @HiveField(11)
  double unitPrice;

  RestockItem({
    required this.name,
    required this.category,
    this.unit = 'pcs',
    this.location = 'Pantry',
    this.estimatedPrice = 0,
    DateTime? dateAdded,
    this.bought = false,
    this.datePurchased,
    this.packageCount = 1,
    this.packageType = 'pack',
    this.packageSize = 1,
    this.unitPrice = 0,
  }) : dateAdded = dateAdded ?? DateTime.now();

  // Example: 4 packs x 1 kg = 4 kg.
  double get totalQuantity => packageCount * packageSize;

  // Price of all packages.
  double get totalPackagePrice => packageCount * unitPrice;

  bool get isPending => !bought;

  bool get isPurchased => bought;

  String get packageDescription {
    final count = packageCount > 0 ? packageCount : 1;

    final sizeText = packageSize == packageSize.roundToDouble()
        ? packageSize.toInt().toString()
        : packageSize.toStringAsFixed(2);

    return '$count $packageType × $sizeText $unit';
  }
}
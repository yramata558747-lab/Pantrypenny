import 'package:hive/hive.dart';

part 'pantry_item.g.dart';

@HiveType(typeId: 0)
class PantryItem extends HiveObject {
  @HiveField(0)
  String name;

  // Total remaining quantity.
  // Example: 100 bottles x 250 mL = 25000 mL.
  @HiveField(1)
  double amount;

  @HiveField(2)
  String unit;

  @HiveField(3)
  String category;

  @HiveField(4)
  String location;

  // Retained for compatibility with older Hive data.
  @HiveField(5)
  DateTime expirationDate;

  @HiveField(6)
  DateTime purchaseDate;

  // Number of packages remaining.
  @HiveField(7)
  int packageCount;

  // Quantity contained in ONE package.
  @HiveField(8)
  double packageSize;

  @HiveField(9)
  String packageType;

  @HiveField(10)
  double pricePerPackage;

  @HiveField(11)
  double totalPrice;

  // Cloudinary image URL (empty when the item has no photo).
  @HiveField(12)
  String imageUrl;

  // Firestore document id used to mirror this item to the cloud.
  @HiveField(13)
  String cloudId;

  PantryItem({
    required this.name,
    required this.amount,
    required this.unit,
    this.category = 'Other',
    required this.location,
    DateTime? expirationDate,
    DateTime? purchaseDate,
    int? packageCount,
    double? packageSize,
    this.packageType = 'pack',
    this.pricePerPackage = 0,
    this.totalPrice = 0,
    this.imageUrl = '',
    String? cloudId,
  })  : cloudId = cloudId ?? '',
        expirationDate =
            expirationDate ?? DateTime(2100),
        purchaseDate =
            purchaseDate ?? DateTime.now(),
        packageCount = packageCount ??
            ((packageSize != null && packageSize > 0)
                ? (amount / packageSize).ceil()
                : 1),
        packageSize = packageSize ?? amount;

  double get totalPackageQuantity =>
      packageCount * packageSize;

  double get remainingPackages {
    if (packageSize <= 0) return 0;
    return amount / packageSize;
  }

  int get fullPackagesRemaining {
    if (packageSize <= 0) return 0;

    // Small tolerance for floating-point rounding.
    return ((amount / packageSize) + 0.0000001).floor();
  }

  bool get isEmpty => amount <= 0;

  void usePackages(int count) {
    if (count <= 0 || packageSize <= 0) return;

    final available = fullPackagesRemaining;

    if (available <= 0) return;

    final actualCount =
        count > available ? available : count;

    final used = actualCount * packageSize;

    amount = (amount - used)
        .clamp(0.0, double.infinity)
        .toDouble();

    packageCount = fullPackagesRemaining;
  }

  void useAll() {
    amount = 0;
    packageCount = 0;
  }

  // Retained for older screens.
  int get daysUntilExpiration => 99999;

  bool get isUseFirst => false;
}
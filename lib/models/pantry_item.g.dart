part of 'pantry_item.dart';

class PantryItemAdapter extends TypeAdapter<PantryItem> {
  @override
  final int typeId = 0;

  // ============================================================
  // SAFE DATA CONVERSION
  // Supports older saved Hive records.
  // ============================================================

  double _toDouble(
    dynamic value, [
    double fallback = 0,
  ]) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }

  int _toInt(
    dynamic value, [
    int fallback = 1,
  ]) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ??
          double.tryParse(value.trim())?.toInt() ??
          fallback;
    }

    return fallback;
  }

  String _toString(
    dynamic value,
    String fallback,
  ) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  DateTime? _toDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  // ============================================================
  // READ SAVED PANTRY ITEMS
  // ============================================================

  @override
  PantryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();

    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };

    final amount = _toDouble(fields[1]);

    final storedCount = _toInt(fields[7], 0);
    final storedSize = _toDouble(fields[8]);

    final packageCount = storedCount > 0
        ? storedCount
        : storedSize > 0
            ? (amount / storedSize).ceil()
            : 1;

    final packageSize = storedSize > 0
        ? storedSize
        : packageCount > 0
            ? amount / packageCount
            : amount;

    final totalPrice = _toDouble(fields[11]);

    final savedPricePerPackage =
        _toDouble(fields[10]);

    final pricePerPackage =
        savedPricePerPackage > 0
            ? savedPricePerPackage
            : packageCount > 0
                ? totalPrice / packageCount
                : 0.0;

    return PantryItem(
      name: _toString(fields[0], ''),
      amount: amount,
      unit: _toString(fields[2], 'pcs'),
      category: _toString(fields[3], 'Other'),
      location: _toString(fields[4], 'Pantry'),
      expirationDate:
          _toDate(fields[5]) ?? DateTime(2100),
      purchaseDate:
          _toDate(fields[6]) ?? DateTime.now(),
      packageCount: packageCount,
      packageSize: packageSize,
      packageType: _toString(fields[9], 'pack'),
      pricePerPackage: pricePerPackage,
      totalPrice: totalPrice,
      imageUrl: _toString(fields[12], ''),
      cloudId: _toString(fields[13], ''),
    );
  }

  // ============================================================
  // WRITE PANTRY ITEMS TO HIVE
  // Do not change existing field IDs.
  // ============================================================

  @override
  void write(BinaryWriter writer, PantryItem obj) {
    writer
      ..writeByte(14)

      // Field 0: Name
      ..writeByte(0)
      ..write(obj.name)

      // Field 1: Total remaining amount
      ..writeByte(1)
      ..write(obj.amount)

      // Field 2: Measurement unit
      ..writeByte(2)
      ..write(obj.unit)

      // Field 3: Category
      ..writeByte(3)
      ..write(obj.category)

      // Field 4: Storage location
      ..writeByte(4)
      ..write(obj.location)

      // Field 5: Legacy expiration date
      ..writeByte(5)
      ..write(obj.expirationDate)

      // Field 6: Purchase date
      ..writeByte(6)
      ..write(obj.purchaseDate)

      // Field 7: Number of packages
      ..writeByte(7)
      ..write(obj.packageCount)

      // Field 8: Size of each package
      ..writeByte(8)
      ..write(obj.packageSize)

      // Field 9: Package type
      ..writeByte(9)
      ..write(obj.packageType)

      // Field 10: Price per package
      ..writeByte(10)
      ..write(obj.pricePerPackage)

      // Field 11: Total purchase price
      ..writeByte(11)
      ..write(obj.totalPrice)

      // Field 12: Cloudinary image URL
      ..writeByte(12)
      ..write(obj.imageUrl)

      // Field 13: Firestore document id
      ..writeByte(13)
      ..write(obj.cloudId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PantryItemAdapter &&
            runtimeType == other.runtimeType &&
            typeId == other.typeId;
  }
}
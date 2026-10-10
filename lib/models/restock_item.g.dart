part of 'restock_item.dart';

class RestockItemAdapter extends TypeAdapter<RestockItem> {
  @override
  final int typeId = 1;

  double _toDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }

  int _toInt(dynamic value, [int fallback = 1]) {
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim()) ??
          double.tryParse(value.trim())?.toInt() ??
          fallback;
    }

    return fallback;
  }

  String _toString(dynamic value, String fallback) {
    if (value == null) return fallback;
    return value.toString();
  }

  bool _toBool(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;

    if (value is num) return value != 0;

    if (value is String) {
      final text = value.trim().toLowerCase();

      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }

    return fallback;
  }

  DateTime? _toNullableDate(dynamic value) {
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  @override
  RestockItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();

    // Unknown / legacy field numbers (for example an old field 12)
    // are read and safely ignored.
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };

    final count = _toInt(fields[8]);
    final safeCount = count > 0 ? count : 1;

    final estimatedPrice = _toDouble(fields[4]);

    final storedUnitPrice = _toDouble(fields[11]);

    // Older records may not have a price-per-package value.
    final unitPrice = storedUnitPrice > 0
        ? storedUnitPrice
        : estimatedPrice > 0
            ? estimatedPrice / safeCount
            : 0.0;

    final storedSize = _toDouble(fields[10], 1);

    return RestockItem(
      name: _toString(fields[0], ''),
      category: _toString(fields[1], 'Other'),
      unit: _toString(fields[2], 'pcs'),
      location: _toString(fields[3], 'Pantry'),
      estimatedPrice: estimatedPrice,
      dateAdded:
          _toNullableDate(fields[5]) ?? DateTime.now(),
      bought: _toBool(fields[6]),
      datePurchased: _toNullableDate(fields[7]),
      packageCount: safeCount,
      packageType: _toString(fields[9], 'pack'),
      packageSize: storedSize > 0 ? storedSize : 1,
      unitPrice: unitPrice,
    );
  }

  // Field IDs 0-11 are unchanged, so existing data stays readable.
  @override
  void write(BinaryWriter writer, RestockItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.estimatedPrice)
      ..writeByte(5)
      ..write(obj.dateAdded)
      ..writeByte(6)
      ..write(obj.bought)
      ..writeByte(7)
      ..write(obj.datePurchased)
      ..writeByte(8)
      ..write(obj.packageCount)
      ..writeByte(9)
      ..write(obj.packageType)
      ..writeByte(10)
      ..write(obj.packageSize)
      ..writeByte(11)
      ..write(obj.unitPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestockItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
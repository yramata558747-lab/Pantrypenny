import 'package:flutter/material.dart';

import '../models/restock_item.dart';
import '../theme/pantry_style.dart';

class PackageDetails {
  final int count;
  final double size;
  final String packageType;
  final String unit;
  final String location;
  final double totalPrice;
  final DateTime purchaseDate;

  const PackageDetails({
    required this.count,
    required this.size,
    required this.packageType,
    required this.unit,
    required this.location,
    required this.totalPrice,
    required this.purchaseDate,
  });

  double get totalQuantity => count * size;

  double get pricePerPackage =>
      count > 0 ? totalPrice / count : 0;
}

class PackageDetailsSheet extends StatefulWidget {
  final RestockItem item;

  const PackageDetailsSheet({
    super.key,
    required this.item,
  });

  @override
  State<PackageDetailsSheet> createState() =>
      _PackageDetailsSheetState();
}

class _PackageDetailsSheetState
    extends State<PackageDetailsSheet> {
  late final TextEditingController _countCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _eachPriceCtrl;
  late final TextEditingController _totalPriceCtrl;

  late String _packageType;
  late String _unit;
  late String _location;
  late DateTime _purchaseDate;

  bool _updatingPrice = false;

  static const _packageTypes = [
    'bag',
    'pouch',
    'pack',
    'bottle',
    'can',
    'box',
    'carton',
    'tray',
    'piece',
  ];

  static const _units = [
    'pcs',
    'kg',
    'grams',
    'liters',
    'mL',
  ];

  static const _locations = [
    'Pantry',
    'Fridge',
    'Freezer',
  ];

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _countCtrl = TextEditingController(
      text: item.packageCount.toString(),
    );

    _sizeCtrl = TextEditingController(
      text: _format(item.packageSize),
    );

    _eachPriceCtrl = TextEditingController(
      text: item.unitPrice > 0
          ? item.unitPrice.toStringAsFixed(2)
          : '',
    );

    _totalPriceCtrl = TextEditingController(
      text: item.estimatedPrice > 0
          ? item.estimatedPrice.toStringAsFixed(2)
          : '',
    );

    _packageType = _packageTypes.contains(item.packageType)
        ? item.packageType
        : 'pack';

    _unit = _units.contains(item.unit)
        ? item.unit
        : 'pcs';

    _location = _locations.contains(item.location)
        ? item.location
        : 'Pantry';

    _purchaseDate =
        item.datePurchased ?? DateTime.now();
  }

  static String _format(double value) {
    if (!value.isFinite) return '0';

    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  int get _count =>
      int.tryParse(_countCtrl.text.trim()) ?? 0;

  double get _size =>
      double.tryParse(_sizeCtrl.text.trim()) ?? 0;

  double get _totalQuantity => _count * _size;

  void _pricePerPackageChanged(String value) {
    if (_updatingPrice) return;

    _updatingPrice = true;

    final each = double.tryParse(value) ?? 0;
    final total = each * _count;

    _totalPriceCtrl.text =
        total > 0 ? total.toStringAsFixed(2) : '';

    _updatingPrice = false;
    setState(() {});
  }

  void _totalPriceChanged(String value) {
    if (_updatingPrice) return;

    _updatingPrice = true;

    final total = double.tryParse(value) ?? 0;
    final each = _count > 0 ? total / _count : 0.0;

    _eachPriceCtrl.text =
        each > 0 ? each.toStringAsFixed(2) : '';

    _updatingPrice = false;
    setState(() {});
  }

  void _countChanged(String value) {
    _updatingPrice = true;

    final each = double.tryParse(_eachPriceCtrl.text) ?? 0;
    final total = double.tryParse(_totalPriceCtrl.text) ?? 0;

    if (each > 0 && _count > 0) {
      _totalPriceCtrl.text =
          (each * _count).toStringAsFixed(2);
    } else if (total > 0 && _count > 0) {
      _eachPriceCtrl.text =
          (total / _count).toStringAsFixed(2);
    }

    _updatingPrice = false;
    setState(() {});
  }

  Future<void> _pickPurchaseDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _purchaseDate.isAfter(now)
          ? now
          : _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Select Date Purchased',
    );

    if (date != null && mounted) {
      setState(() => _purchaseDate = date);
    }
  }

  void _save() {
    final count = _count;
    final size = _size;

    final totalPrice =
        double.tryParse(_totalPriceCtrl.text.trim()) ?? 0;

    if (count < 1 ||
        size <= 0 ||
        !size.isFinite ||
        totalPrice < 0 ||
        !totalPrice.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid package count, size, and price.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      PackageDetails(
        count: count,
        size: size,
        packageType: _packageType,
        unit: _unit,
        location: _location,
        totalPrice: totalPrice,
        purchaseDate: _purchaseDate,
      ),
    );
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _sizeCtrl.dispose();
    _eachPriceCtrl.dispose();
    _totalPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: PantryStyle.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            bottomInset + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: PantryStyle.cardBorder,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Purchase ${widget.item.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PantryStyle.ink,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Enter package quantity, size, price and purchase date.',
                  style: TextStyle(
                    color: PantryStyle.inkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countCtrl,
                        keyboardType:
                            TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'No. of packages',
                          hintText: '5',
                        ),
                        onChanged: _countChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _packageType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Package type',
                        ),
                        items: _packageTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                              () => _packageType = value,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sizeCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Size each',
                          hintText: '100',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                        ),
                        items: _units.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _unit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F1EB),
                    borderRadius:
                        BorderRadius.circular(17),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL INVENTORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PantryStyle.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_format(_totalQuantity)} $_unit',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: PantryStyle.primaryDark,
                        ),
                      ),
                      Text(
                        '$_count $_packageType(s) × '
                        '${_format(_size)} $_unit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PantryStyle.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Grocery Price',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _eachPriceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price per package',
                          prefixText: '₱ ',
                        ),
                        onChanged:
                            _pricePerPackageChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _totalPriceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Total price',
                          prefixText: '₱ ',
                        ),
                        onChanged: _totalPriceChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _location,
                  decoration: const InputDecoration(
                    labelText: 'Storage location',
                  ),
                  items: _locations.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _location = value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Date Purchased',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PantryStyle.ink,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickPurchaseDate,
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                    ),
                    label: Text(
                      _formatDate(_purchaseDate),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          PantryStyle.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(
                      Icons.check_circle_outline,
                    ),
                    label: const Text(
                      'Confirm Purchase',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          PantryStyle.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
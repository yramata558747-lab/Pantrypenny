import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restock_provider.dart';
import '../theme/pantry_style.dart';

class AddRestockSheet extends StatefulWidget {
  const AddRestockSheet({super.key});

  @override
  State<AddRestockSheet> createState() =>
      _AddRestockSheetState();
}

class _AddRestockSheetState extends State<AddRestockSheet> {
  final _nameCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');
  final _sizeCtrl = TextEditingController(text: '1');
  final _eachCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  String _packageType = 'pack';
  String _unit = 'pcs';
  String _location = 'Pantry';
  bool _saving = false;

  static const _packages = [
    'pack',
    'bag',
    'pouch',
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

  int get _count =>
      int.tryParse(_countCtrl.text.trim()) ?? 0;

  double get _size =>
      double.tryParse(_sizeCtrl.text.trim()) ?? 0;

  String _fmt(double value) {
    if (!value.isFinite) return '0';

    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  void _updateFromEach(String value) {
    final each = double.tryParse(value) ?? 0;

    _totalCtrl.text = each > 0 && _count > 0
        ? (each * _count).toStringAsFixed(2)
        : '';

    setState(() {});
  }

  void _updateFromTotal(String value) {
    final total = double.tryParse(value) ?? 0;

    _eachCtrl.text = total > 0 && _count > 0
        ? (total / _count).toStringAsFixed(2)
        : '';

    setState(() {});
  }

  void _updateCount(String value) {
    final each = double.tryParse(_eachCtrl.text) ?? 0;
    final total = double.tryParse(_totalCtrl.text) ?? 0;

    if (each > 0 && _count > 0) {
      _totalCtrl.text = (each * _count).toStringAsFixed(2);
    } else if (total > 0 && _count > 0) {
      _eachCtrl.text = (total / _count).toStringAsFixed(2);
    }

    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final count = _count;
    final size = _size;

    final total =
        double.tryParse(_totalCtrl.text.trim()) ?? 0;

    if (name.isEmpty ||
        count < 1 ||
        size <= 0 ||
        !size.isFinite ||
        total < 0 ||
        !total.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid grocery details.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<RestockProvider>().addGrocery(
            name: name,
            category: 'Other',
            count: count,
            size: size,
            packageType: _packageType,
            unit: _unit,
            location: _location,
            totalPrice: total,
          );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to save grocery item: '
              '${error.toString().replaceFirst("Bad state: ", "")}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countCtrl.dispose();
    _sizeCtrl.dispose();
    _eachCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Grocery Item',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PantryStyle.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Plan your packages, quantities and spending.',
                  style: TextStyle(
                    color: PantryStyle.inkSoft,
                  ),
                ),
                const SizedBox(height: 20),

                // ITEM NAME
                TextField(
                  controller: _nameCtrl,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Shampoo, Rice, Milk',
                    prefixIcon: Icon(
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // PACKAGE COUNT AND TYPE
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countCtrl,
                        keyboardType:
                            TextInputType.number,
                        decoration:
                            const InputDecoration(
                          labelText: 'No. of packages',
                        ),
                        onChanged: _updateCount,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child:
                          DropdownButtonFormField<String>(
                        value: _packageType,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(
                          labelText: 'Package type',
                        ),
                        items: _packages.map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value),
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

                // PACKAGE SIZE AND UNIT
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sizeCtrl,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Size per package',
                        ),
                        onChanged: (_) =>
                            setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child:
                          DropdownButtonFormField<String>(
                        value: _unit,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(
                          labelText: 'Unit',
                        ),
                        items: _units.map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                              () => _unit = value,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // TOTAL QUANTITY PREVIEW
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F1EB),
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL QUANTITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color:
                              PantryStyle.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_fmt(_count * _size)} $_unit',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color:
                              PantryStyle.primaryDark,
                        ),
                      ),
                      Text(
                        '$_count $_packageType(s) × '
                        '${_fmt(_size)} $_unit',
                        style: const TextStyle(
                          color: PantryStyle.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Grocery Budget',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 12),

                // PRICE INPUTS
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _eachCtrl,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Price per package',
                          prefixText: '₱ ',
                        ),
                        onChanged: _updateFromEach,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _totalCtrl,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Total price',
                          prefixText: '₱ ',
                        ),
                        onChanged: _updateFromTotal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // STORAGE LOCATION
                DropdownButtonFormField<String>(
                  value: _location,
                  decoration: const InputDecoration(
                    labelText: 'Storage location',
                    prefixIcon: Icon(
                      Icons.kitchen_outlined,
                    ),
                  ),
                  items: _locations.map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(
                        () => _location = value,
                      );
                    }
                  },
                ),

                const SizedBox(height: 22),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _saving ? null : _save,
                    icon: const Icon(
                      Icons.add_rounded,
                    ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : 'Add to Grocery List',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          PantryStyle.primaryDark,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(
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
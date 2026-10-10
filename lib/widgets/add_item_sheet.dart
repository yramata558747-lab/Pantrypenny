import 'dart:io';

import 'package:flutter/material.dart';

import '../models/pantry_item.dart';
import '../services/crud_service.dart';
import '../theme/pantry_style.dart';

const kUnits = ['pcs', 'kg', 'grams', 'liters', 'mL'];
const kLocations = ['Fridge', 'Freezer', 'Pantry'];

class AddItemSheet extends StatefulWidget {
  final PantryItem? prefill;
  final String? photoHint;
  final bool isEdit;

  const AddItemSheet({
    super.key,
    this.prefill,
    this.photoHint,
    this.isEdit = false,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _sizeCtrl;

  String _packageType = 'pack';
  String _unit = 'pcs';
  String _location = 'Pantry';
  late DateTime _purchaseDate;

  // Item photo (uploaded to Cloudinary).
  final CrudService _crud = CrudService();
  String _imageUrl = '';
  File? _localImage;
  bool _uploading = false;

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

  @override
  void initState() {
    super.initState();

    final item = widget.prefill;

    _nameCtrl = TextEditingController(
      text: item?.name ?? '',
    );

    _countCtrl = TextEditingController(
      text: (item?.packageCount ?? 1).toString(),
    );

    _sizeCtrl = TextEditingController(
      text: _format(
        item?.packageSize ?? item?.amount ?? 1,
      ),
    );

    _purchaseDate =
        item?.purchaseDate ?? DateTime.now();

    _imageUrl = item?.imageUrl ?? '';

    if (item != null) {
      if (_packages.contains(item.packageType)) {
        _packageType = item.packageType;
      }

      _unit = kUnits.contains(item.unit)
          ? item.unit
          : 'pcs';

      _location = kLocations.contains(item.location)
          ? item.location
          : 'Pantry';
    }
  }

  String _format(double value) {
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

  Future<void> _pickImage() async {
    if (_uploading) return;

    setState(() => _uploading = true);

    try {
      final picked = await _crud.pickImageForAddItem();

      if (!mounted) return;

      if (picked != null) {
        setState(() {
          _localImage = picked.file;
          _imageUrl = picked.url;
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to upload photo. Check your internet '
            'connection and Cloudinary settings.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _photoSection() {
    final hasImage = _imageUrl.isNotEmpty;

    final placeholder = Container(
      height: 140,
      width: double.infinity,
      color: const Color(0xFFE7F1EB),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: PantryStyle.inkSoft,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Photo',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PantryStyle.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (hasImage) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _localImage != null
                    ? Image.file(
                        _localImage!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        _imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => placeholder,
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filled(
                  tooltip: 'Remove photo',
                  onPressed: () => setState(() {
                    _imageUrl = '';
                    _localImage = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _pickImage,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _uploading
                  ? 'Uploading...'
                  : hasImage
                      ? 'Change Photo'
                      : 'Add Photo',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: PantryStyle.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final count = _count;
    final size = _size;

    if (name.isEmpty ||
        count < 1 ||
        size <= 0 ||
        !size.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an item name and valid package quantity.',
          ),
        ),
      );
      return;
    }

    final original = widget.prefill;

    final item = PantryItem(
      name: name,
      amount: count * size,
      unit: _unit,
      category: original?.category ?? 'Other',
      location: _location,
      purchaseDate: _purchaseDate,
      expirationDate: original?.expirationDate,
      packageCount: count,
      packageSize: size,
      packageType: _packageType,
      imageUrl: _imageUrl,
      pricePerPackage:
          original?.pricePerPackage ?? 0,
      totalPrice:
          (original?.pricePerPackage ?? 0) * count,
    );

    Navigator.pop(context, item);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countCtrl.dispose();
    _sizeCtrl.dispose();
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
                Text(
                  widget.isEdit
                      ? 'Edit Pantry Item'
                      : 'Add to My Pantry',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PantryStyle.ink,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Track the items you purchased.',
                  style: TextStyle(
                    color: PantryStyle.inkSoft,
                  ),
                ),

                if (widget.photoHint != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F1EB),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.photoHint!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PantryStyle.primaryDark,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                TextField(
                  controller: _nameCtrl,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Rice',
                    prefixIcon: Icon(
                      Icons.inventory_2_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'No. of packages',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _packageType,
                        isExpanded: true,
                        decoration: const InputDecoration(
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
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                        ),
                        items: kUnits.map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value),
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

                const SizedBox(height: 17),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
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
                        'TOTAL PANTRY STOCK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PantryStyle.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_format(_count * _size)} $_unit',
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

                const SizedBox(height: 18),

                _photoSection(),

                const SizedBox(height: 18),

                DropdownButtonFormField<String>(
                  value: _location,
                  decoration: const InputDecoration(
                    labelText: 'Storage location',
                    prefixIcon: Icon(
                      Icons.kitchen_outlined,
                    ),
                  ),
                  items: kLocations.map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value),
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

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : _save,
                    icon: const Icon(
                      Icons.check_rounded,
                    ),
                    label: Text(
                      widget.isEdit
                          ? 'Save Changes'
                          : 'Save to Pantry',
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
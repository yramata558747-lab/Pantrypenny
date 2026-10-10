import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pantry_item.dart';
import '../models/pantry_provider.dart';
import '../models/restock_provider.dart';
import '../theme/pantry_style.dart';
import '../widgets/add_item_sheet.dart';
import '../widgets/account_sheet.dart';
import '../widgets/pantry_item_card.dart';

import 'cloud_pantry_screen.dart';
import 'lens_scan_screen.dart';
import 'restock_screen.dart';
import 'usage_history_screen.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _search = '';
  String _location = 'All';
  bool _busy = false;

  static const List<String> _locations = [
    'All',
    'Pantry',
    'Fridge',
    'Freezer',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _format(double value) {
    if (!value.isFinite) return '0';

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  List<PantryItem> _filteredItems(
    List<PantryItem> items,
  ) {
    return items.where((item) {
      final matchesName = item.name
          .toLowerCase()
          .contains(_search.toLowerCase());

      final matchesLocation =
          _location == 'All' ||
          item.location.toLowerCase() ==
              _location.toLowerCase();

      return matchesName && matchesLocation;
    }).toList();
  }

  Future<void> _addItem() async {
    final item = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.90,
        child: AddItemSheet(),
      ),
    );

    if (!mounted || item == null) return;

    try {
      await context.read<PantryProvider>().addItem(item);
      _message('${item.name} added to My Pantry');
    } catch (error) {
      _message('Unable to add item: $error');
    }
  }

  Future<void> _scanAndAdd() async {
    final result = await Navigator.push<LensResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const LensScanScreen(),
      ),
    );

    if (!mounted || result == null) return;

    final prefill = PantryItem(
      name: result.name,
      amount: 1,
      unit: 'pcs',
      category: result.category,
      location: 'Pantry',
      purchaseDate: DateTime.now(),
      packageCount: 1,
      packageSize: 1,
      packageType: 'pack',
    );

    final hint = result.confidence > 0
        ? 'Detected "${result.name}" '
          '(${(result.confidence * 100).round()}% confidence). '
          'Review the details before saving.'
        : 'Review the detected item before saving.';

    final item = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: AddItemSheet(
          prefill: prefill,
          photoHint: hint,
        ),
      ),
    );

    if (!mounted || item == null) return;

    try {
      await context.read<PantryProvider>().addItem(item);
      _message('${item.name} added from AI Scan');
    } catch (error) {
      _message('Unable to save scanned item: $error');
    }
  }

  void _openGrocery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RestockScreen(),
      ),
    );
  }

  void _openUsageHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UsageHistoryScreen(),
      ),
    );
  }

  void _openCloud() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CloudPantryScreen(),
      ),
    );
  }

  Future<void> _editItem(PantryItem item) async {
    final edited = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: AddItemSheet(
          prefill: item,
          isEdit: true,
        ),
      ),
    );

    if (!mounted || edited == null || !item.isInBox) return;

    try {
      await context
          .read<PantryProvider>()
          .updateItem(item, edited);

      _message('${edited.name} updated');
    } catch (error) {
      _message('Unable to update item: $error');
    }
  }

  void _openAccount() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AccountSheet(),
    );
  }

  Future<void> _useItem(PantryItem item) async {
    if (_busy) return;

    final available = item.fullPackagesRemaining;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(
          22, 14, 22, 28,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: SafeArea(
          top: false,
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
                    color: Colors.black12,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Use ${item.name}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: PantryStyle.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: $available '
                '${item.packageType}'
                '${available == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: PantryStyle.inkSoft,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Each ${item.packageType}: '
                '${_format(item.packageSize)} '
                '${item.unit}',
                style: const TextStyle(
                  color: PantryStyle.inkSoft,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: available > 0
                      ? () => Navigator.pop(
                            sheetContext,
                            'one',
                          )
                      : null,
                  icon: const Icon(
                    Icons.remove_circle_outline,
                  ),
                  label: const Text('Use 1 Package'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        PantryStyle.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    'all',
                  ),
                  icon: const Icon(
                    Icons.inventory_2_outlined,
                  ),
                  label: const Text('Use All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        PantryStyle.primaryDark,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null || !item.isInBox) {
      return;
    }

    setState(() => _busy = true);

    try {
      final pantry = context.read<PantryProvider>();

      // Preserve the package information before
      // using an item that might be removed from Hive.
      final name = item.name;
      final category = item.category;
      final unit = item.unit;
      final location = item.location;
      final packageCount = item.packageCount;
      final packageSize = item.packageSize;
      final packageType = item.packageType;
      final pricePerPackage = item.pricePerPackage;

      final depleted = action == 'all' ||
          (action == 'one' &&
              item.amount <= item.packageSize);

      if (action == 'one') {
        await pantry.usePackages(item, 1);
        _message('Used 1 $packageType of $name');
      } else {
        await pantry.useAll(item);
        _message('Used all remaining $name');
      }

      if (!mounted) return;

      // Add depleted stock to Go Grocery so it
      // can be purchased again using saved details.
      if (depleted) {
        final originalCount =
            packageCount > 0 ? packageCount : 1;

        await context.read<RestockProvider>().buyAgain({
          'name': name,
          'category': category,
          'unit': unit,
          'location': location,
          'packageCount': originalCount,
          'originalPackageCount': originalCount,
          'packageSize': packageSize,
          'packageType': packageType,
          'pricePerPackage': pricePerPackage,
          'totalPrice':
              pricePerPackage * originalCount,
        });
      }
    } catch (error) {
      _message('Unable to update item: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteItem(PantryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove pantry item?'),
        content: Text(
          'Remove ${item.name} from My Pantry?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await context
          .read<PantryProvider>()
          .removeItem(item);

      _message('${item.name} removed');
    } catch (error) {
      _message('Unable to remove item: $error');
    }
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: PantryStyle.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: PantryStyle.primaryDark,
              size: 23,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: PantryStyle.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: PantryStyle.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: PantryStyle.primaryDark,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 5,
          ),
          side: const BorderSide(
            color: PantryStyle.cardBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final allItems = pantry.items;
    final items = _filteredItems(allItems);

    final totalPackages = allItems.fold<int>(
      0,
      (total, item) =>
          total + item.fullPackagesRemaining,
    );

    return Scaffold(
      backgroundColor: PantryStyle.surface,
      appBar: AppBar(
        backgroundColor: PantryStyle.surface,
        title: const Text(
          'PantryPenny',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: PantryStyle.primaryDark,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cloud Pantry',
            onPressed: _openCloud,
            icon: const Icon(
              Icons.cloud_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Usage History',
            onPressed: _openUsageHistory,
            icon: const Icon(
              Icons.history_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: _openAccount,
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: PantryStyle.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18, 12, 18, 95,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: PantryStyle.headerGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${allItems.length}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        allItems.length == 1 ? 'item' : 'items',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _scanAndAdd,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'AI Scan',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: PantryStyle.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              _summaryCard(
                'Pantry Items',
                '${allItems.length}',
                Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'Available Packages',
                '$totalPackages',
                Icons.widgets_outlined,
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PantryStyle.ink,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _quickAction(
                'Add Item',
                Icons.add_box_outlined,
                _addItem,
              ),
              const SizedBox(width: 9),
              _quickAction(
                'AI Scan',
                Icons.camera_alt_outlined,
                _scanAndAdd,
              ),
              const SizedBox(width: 9),
              _quickAction(
                'Go Grocery',
                Icons.shopping_cart_outlined,
                _openGrocery,
              ),
              const SizedBox(width: 9),
              _quickAction(
                'Usage History',
                Icons.history_rounded,
                _openUsageHistory,
              ),
            ],
          ),

          const SizedBox(height: 23),

          const Text(
            'Your Pantry Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PantryStyle.ink,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _search = value);
            },
            decoration: InputDecoration(
              hintText: 'Search pantry items',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: PantryStyle.cardBorder,
                ),
              ),
            ),
          ),

          const SizedBox(height: 13),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _locations.map((location) {
                final selected = _location == location;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(location),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _location = location);
                    },
                    selectedColor:
                        const Color(0xFFE7F1EB),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? PantryStyle.primaryDark
                          : PantryStyle.inkSoft,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 17),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PantryStyle.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: PantryStyle.inkSoft,
                  ),
                  const SizedBox(height: 13),
                  Text(
                    allItems.isEmpty
                        ? 'Your pantry is empty'
                        : 'No matching items',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: PantryStyle.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    allItems.isEmpty
                        ? 'Add an item to start tracking '
                          'your pantry stock.'
                        : 'Try a different search or '
                          'storage location.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PantryStyle.inkSoft,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PantryItemCard(
                  item: item,
                  onUse: _busy
                      ? null
                      : () => _useItem(item),
                  onEdit: _busy
                      ? null
                      : () => _editItem(item),
                  onDelete: _busy
                      ? null
                      : () => _deleteItem(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
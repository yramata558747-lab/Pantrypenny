import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pantry_provider.dart';
import '../models/restock_item.dart';
import '../models/restock_provider.dart';
import '../theme/pantry_style.dart';
import '../widgets/add_restock_sheet.dart';
import '../widgets/package_details_sheet.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  bool _showHistory = false;
  bool _processing = false;

  String _money(double amount) =>
      '₱${amount.toStringAsFixed(2)}';

  String _quantity(double amount) {
    if (!amount.isFinite) return '0';
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
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

  Future<void> _addGrocery() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddRestockSheet(),
    );
  }

  Future<void> _editBudget() async {
    final grocery = context.read<RestockProvider>();
    final controller = TextEditingController(
      text: grocery.monthlyBudget.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Monthly Grocery Budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Budget',
            prefixText: '₱ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value =
                  double.tryParse(controller.text);

              if (value == null ||
                  !value.isFinite ||
                  value < 0) {
                return;
              }

              Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Do not dispose a controller while the dialog
    // may still be completing its exit animation.
    if (!mounted || result == null) return;

    try {
      await grocery.setMonthlyBudget(result);
      _message('Budget updated');
    } catch (error) {
      _message('Could not save budget: ${_clean(error)}');
    }
  }

  Future<PackageDetails?> _packageDetails(
    RestockItem item,
  ) {
    return showModalBottomSheet<PackageDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PackageDetailsSheet(item: item),
      ),
    );
  }

  Future<void> _editPackage(RestockItem item) async {
    final grocery = context.read<RestockProvider>();

    final details = await _packageDetails(item);
    if (!mounted || details == null) return;

    try {
      await grocery.configurePackage(
            item,
            count: details.count,
            size: details.size,
            packageType: details.packageType,
            unit: details.unit,
            location: details.location,
            totalPrice: details.totalPrice,
          );

      _message('Package details updated');
    } catch (error) {
      _message('Could not update item: ${_clean(error)}');
    }
  }

  String _clean(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');

  Future<void> _purchase(RestockItem item) async {
    if (_processing || item.bought) return;

    final grocery = context.read<RestockProvider>();
    final pantry = context.read<PantryProvider>();

    final details = await _packageDetails(item);
    if (!mounted || details == null) return;

    setState(() => _processing = true);

    try {
      // Step 1: save final package details + mark as purchased
      // (one Hive write). This also fills Purchase History and
      // the monthly spending total.
      try {
        await grocery.completePurchase(
          item,
          count: details.count,
          size: details.size,
          packageType: details.packageType,
          unit: details.unit,
          location: details.location,
          totalPrice: details.totalPrice,
          purchaseDate: details.purchaseDate,
        );
      } catch (error) {
        _message('Could not complete purchase: ${_clean(error)}');
        return;
      }

      // Step 2: transfer the stock to My Pantry.
      try {
        await pantry.addPurchasedItem(
          name: item.name,
          amount: details.totalQuantity,
          unit: details.unit,
          category: item.category,
          location: details.location,
          purchaseDate: details.purchaseDate,
          packageCount: details.count,
          packageSize: details.size,
          packageType: details.packageType,
          pricePerPackage: details.pricePerPackage,
          totalPrice: details.totalPrice,
        );
      } catch (error) {
        // Put the item back in Go Grocery so nothing is lost.
        try {
          await grocery.undoPurchase(item);
        } catch (_) {}

        _message(
          'Could not add ${item.name} to My Pantry: '
          '${_clean(error)}. The item is still in Go Grocery.',
        );
        return;
      }

      _message(
        '${item.name} added to My Pantry and Purchase History',
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _remove(RestockItem item) async {
    final grocery = context.read<RestockProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove grocery item?'),
        content: Text(
          'Remove ${item.name} from the grocery list?',
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
            child: const Text(
              'Remove',
              style: TextStyle(color: PantryStyle.danger),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await grocery.removeFromRestock(item);
      _message('${item.name} removed');
    } catch (error) {
      _message('Could not remove item: ${_clean(error)}');
    }
  }

  Widget _budgetCard(RestockProvider grocery) {
    final budget = grocery.monthlyBudget;
    final spent = grocery.spentThisMonth;
    final remaining = grocery.remainingBudget;

    final progress = budget > 0
        ? (spent / budget).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: PantryStyle.headerGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly Grocery Budget',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: _editBudget,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            _money(budget),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.white24,
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _budgetLabel(
                  'Spent this month',
                  _money(spent),
                ),
              ),
              Expanded(
                child: _budgetLabel(
                  'Remaining',
                  _money(remaining),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _budgetLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: PantryStyle.inkSoft,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: PantryStyle.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groceryCard(RestockItem item) {
    final count = item.packageCount;
    final quantity = item.packageSize * count;
    final pricePer = item.unitPrice > 0
        ? item.unitPrice
        : (count > 0 ? item.estimatedPrice / count : 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: PantryStyle.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F1EB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: PantryStyle.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PantryStyle.ink,
                  ),
                ),
              ),
              if (!item.bought)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPackage(item);
                    } else if (value == 'delete') {
                      _remove(item);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Package Details'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow(
            'Quantity',
            '$count ${item.packageType}'
                '${count == 1 ? '' : 's'}',
          ),
          _detailRow(
            'Size per package',
            '${_quantity(item.packageSize)} ${item.unit}',
          ),
          _detailRow(
            'Total quantity',
            '${_quantity(quantity)} ${item.unit}',
          ),
          _detailRow(
            'Price per package',
            _money(pricePer),
          ),
          _detailRow('Storage', item.location),
          const Divider(height: 22),
          Row(
            children: [
              const Text(
                'Total price',
                style: TextStyle(
                  fontSize: 13,
                  color: PantryStyle.inkSoft,
                ),
              ),
              const Spacer(),
              Text(
                _money(item.estimatedPrice),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: PantryStyle.primaryDark,
                ),
              ),
            ],
          ),
          if (item.bought) ...[
            const SizedBox(height: 6),
            Text(
              'Purchased: '
              '${item.datePurchased?.month ?? '-'}'
              '/${item.datePurchased?.day ?? '-'}'
              '/${item.datePurchased?.year ?? '-'}',
              style: const TextStyle(
                fontSize: 12,
                color: PantryStyle.inkSoft,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _processing
                    ? null
                    : () => _purchase(item),
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 19,
                ),
                label: const Text('Mark Purchased'),
                style: FilledButton.styleFrom(
                  backgroundColor: PantryStyle.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grocery = context.watch<RestockProvider>();

    final visibleItems =
        _showHistory ? grocery.history : grocery.pending;

    return Scaffold(
      backgroundColor: PantryStyle.surface,
      appBar: AppBar(
        title: const Text(
          'Go Grocery',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _addGrocery,
            icon: const Icon(
              Icons.add_shopping_cart_outlined,
            ),
            tooltip: 'Add Grocery',
          ),
        ],
      ),
      floatingActionButton: _showHistory
          ? null
          : FloatingActionButton.extended(
              onPressed: _addGrocery,
              backgroundColor: PantryStyle.primaryDark,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Grocery'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18, 18, 18, 90,
        ),
        children: [
          _budgetCard(grocery),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _tab(
                  'Go Grocery',
                  !_showHistory,
                  () => setState(
                    () => _showHistory = false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tab(
                  'Purchase History',
                  _showHistory,
                  () => setState(
                    () => _showHistory = true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _showHistory
                ? '${visibleItems.length} purchased items'
                : '${visibleItems.length} items to buy',
            style: const TextStyle(
              color: PantryStyle.inkSoft,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 13),
          if (visibleItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: PantryStyle.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _showHistory
                        ? Icons.receipt_long_outlined
                        : Icons.shopping_cart_outlined,
                    size: 45,
                    color: PantryStyle.inkSoft,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _showHistory
                        ? 'No purchases yet'
                        : 'Your grocery list is empty',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PantryStyle.ink,
                    ),
                  ),
                ],
              ),
            ),
          ...visibleItems.map(_groceryCard),
        ],
      ),
    );
  }

  Widget _tab(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? PantryStyle.primaryDark
              : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? PantryStyle.primaryDark
                : PantryStyle.cardBorder,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected
                ? Colors.white
                : PantryStyle.ink,
          ),
        ),
      ),
    );
  }
}
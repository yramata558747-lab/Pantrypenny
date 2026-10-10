
import 'package:flutter/material.dart';
import '../models/pantry_item.dart';
import '../theme/pantry_style.dart';

class UseAmountSheet extends StatefulWidget {
  final PantryItem item;

  const UseAmountSheet({
    super.key,
    required this.item,
  });

  @override
  State<UseAmountSheet> createState() =>
      _UseAmountSheetState();
}

class _UseAmountSheetState extends State<UseAmountSheet> {
  int _selectedPackages = 1;

  PantryItem get item => widget.item;

  int get _availablePackages {
    if (item.amount <= 0) return 0;

    if (item.packageSize > 0) {
      final full = item.fullPackagesRemaining;

      // Include a partially remaining package if needed.
      final remainder =
          item.amount - (full * item.packageSize);

      return full +
          (remainder > 0.000001 ? 1 : 0);
    }

    return item.packageCount > 0
        ? item.packageCount
        : 1;
  }

  double get _amountToUse {
    final size = item.packageSize > 0
        ? item.packageSize
        : item.amount;

    final amount = _selectedPackages * size;

    return amount > item.amount
        ? item.amount
        : amount;
  }

  String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  void _increase() {
    if (_selectedPackages < _availablePackages) {
      setState(() {
        _selectedPackages++;
      });
    }
  }

  void _decrease() {
    if (_selectedPackages > 1) {
      setState(() {
        _selectedPackages--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _availablePackages;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: PantryStyle.cardBorder,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Use ${item.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: PantryStyle.ink,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '$available ${item.packageType}'
              '${available == 1 ? '' : 's'} available',
              style: const TextStyle(
                fontSize: 13,
                color: PantryStyle.inkSoft,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '${_format(item.packageSize)} '
              '${item.unit} per ${item.packageType}',
              style: const TextStyle(
                fontSize: 12,
                color: PantryStyle.inkSoft,
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'How many packages did you use?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PantryStyle.ink,
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  icon: Icons.remove_rounded,
                  onTap: _selectedPackages > 1
                      ? _decrease
                      : null,
                ),

                SizedBox(
                  width: 130,
                  child: Column(
                    children: [
                      Text(
                        '$_selectedPackages',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: PantryStyle.ink,
                        ),
                      ),
                      Text(
                        item.packageType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PantryStyle.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),

                _RoundButton(
                  icon: Icons.add_rounded,
                  onTap:
                      _selectedPackages < available
                          ? _increase
                          : null,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: PantryStyle.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'Quantity to be deducted',
                    style: TextStyle(
                      fontSize: 12,
                      color: PantryStyle.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_format(_amountToUse)} ${item.unit}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PantryStyle.primaryDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: available <= 0
                  ? null
                  : () => Navigator.pop(
                        context,
                        item.amount,
                      ),
              icon: const Icon(
                Icons.delete_sweep_outlined,
                size: 18,
              ),
              label: const Text('Use All'),
              style: TextButton.styleFrom(
                foregroundColor: PantryStyle.danger,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: available <= 0
                    ? null
                    : () => Navigator.pop(
                          context,
                          _amountToUse,
                        ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirm Usage'),
                style: FilledButton.styleFrom(
                  backgroundColor: PantryStyle.primary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PantryStyle.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            color: onTap == null
                ? PantryStyle.inkSoft
                : PantryStyle.primaryDark,
          ),
        ),
      ),
    );
  }
}

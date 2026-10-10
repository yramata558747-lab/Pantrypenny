
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pantry_provider.dart';
import '../models/restock_provider.dart';
import '../theme/pantry_style.dart';

class UsageHistoryScreen extends StatelessWidget {
  const UsageHistoryScreen({super.key});

  String _quantity(dynamic value) {
    final double n;
    if (value is num) {
      n = value.toDouble();
    } else {
      n = double.tryParse(value?.toString() ?? '') ?? 0;
    }

    if (!n.isFinite) return '0';

    if (n == n.roundToDouble()) {
      return n.toInt().toString();
    }

    return n.toStringAsFixed(2);
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(
      value?.toString() ?? '',
    )?.toLocal();

    if (date == null) return 'Unknown date';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final hour = date.hour % 12 == 0
        ? 12
        : date.hour % 12;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} ${date.day}, '
        '${date.year} · $hour:$minute $period';
  }

  String _packageDescription(
    Map<String, dynamic> record,
  ) {
    final count = _quantity(record['packageCount']);
    final size = _quantity(record['packageSize']);
    final type =
        record['packageType']?.toString() ?? 'pack';
    final unit = record['unit']?.toString() ?? 'pcs';

    final countValue =
        double.tryParse(count) ?? 0;

    final sizeValue =
        double.tryParse(size) ?? 0;

    if (countValue <= 0 || sizeValue <= 0) {
      return 'Used ${_quantity(record['amount'])} $unit';
    }

    return 'Used $count $type'
        '${countValue == 1 ? '' : 's'}'
        ' × $size $unit';
  }

  Future<void> _buyAgain(
    BuildContext context,
    Map<String, dynamic> record,
  ) async {
    final grocery = context.read<RestockProvider>();

    final name =
        record['name']?.toString().trim() ?? '';

    if (name.isEmpty) return;

    final exists = grocery.pending.any(
      (item) =>
          item.name.trim().toLowerCase() ==
          name.toLowerCase(),
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Already in your Go Grocery list.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await grocery.buyAgain(record);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name added to Go Grocery with saved '
            'package details and price.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add item: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final history =
        context.watch<PantryProvider>().usageHistory;

    final grocery =
        context.watch<RestockProvider>();

    final pendingNames = grocery.pending
        .map((item) => item.name.trim().toLowerCase())
        .toSet();

    return Scaffold(
      backgroundColor: PantryStyle.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: PantryStyle.ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Usage History',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20, 20, 20, 32,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: PantryStyle.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: PantryStyle.primary
                        .withValues(alpha: 0.09),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: PantryStyle.primaryDark,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items You Have Used',
                        style: TextStyle(
                          color: PantryStyle.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${history.length} usage records',
                        style: const TextStyle(
                          color: PantryStyle.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Need something again? Tap Buy Again to '
            'restore its saved package details and '
            'price in your grocery list.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: PantryStyle.inkSoft,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PantryStyle.ink,
            ),
          ),

          const SizedBox(height: 14),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PantryStyle.cardBorder,
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 46,
                    color: PantryStyle.inkSoft,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No items used yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: PantryStyle.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use an item from My Pantry and '
                    'it will appear here automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PantryStyle.inkSoft,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          ...history.map((record) {
            final name =
                record['name']?.toString() ??
                    'Unknown Item';

            final location =
                record['location']?.toString() ??
                    'Pantry';

            final packageDescription =
                _packageDescription(record);

            final alreadyPending =
                pendingNames.contains(
              name.trim().toLowerCase(),
            );

            final price = _quantity(
              record['totalPrice'],
            );

            return Container(
              margin: const EdgeInsets.only(
                bottom: 12,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: PantryStyle.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: PantryStyle.primary
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color:
                              PantryStyle.primaryDark,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w800,
                                color: PantryStyle.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$location · '
                              '$packageDescription',
                              style: const TextStyle(
                                fontSize: 12,
                                color:
                                    PantryStyle.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _date(record['usedAt']),
                              style: const TextStyle(
                                fontSize: 11,
                                color:
                                    PantryStyle.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Recorded cost: ₱$price',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    PantryStyle.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: alreadyPending
                          ? null
                          : () => _buyAgain(
                                context,
                                record,
                              ),
                      icon: Icon(
                        alreadyPending
                            ? Icons.check_rounded
                            : Icons
                                .add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: Text(
                        alreadyPending
                            ? 'Already in Go Grocery'
                            : 'Buy Again',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            PantryStyle.primaryDark,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        side: const BorderSide(
                          color:
                              PantryStyle.cardBorder,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

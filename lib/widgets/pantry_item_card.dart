import 'package:flutter/material.dart';

import '../models/pantry_item.dart';
import '../theme/pantry_style.dart';

class PantryItemCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onUse;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const PantryItemCard({
    super.key,
    required this.item,
    this.onUse,
    this.onDelete,
    this.onEdit,
  });

  String _format(double value) {
    if (!value.isFinite) return '0';

    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _date(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${months[value.month - 1]} '
        '${value.day}, ${value.year}';
  }

  IconData _locationIcon(String location) {
    switch (location.toLowerCase()) {
      case 'fridge':
        return Icons.kitchen_outlined;
      case 'freezer':
        return Icons.ac_unit_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  // Item photo (Cloudinary) or a location icon fallback.
  Widget _leading() {
    final icon = Icon(
      _locationIcon(item.location),
      color: PantryStyle.primaryDark,
      size: 24,
    );

    return Container(
      width: 47,
      height: 47,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: item.imageUrl.isEmpty
          ? icon
          : Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => icon,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingPackages =
        item.fullPackagesRemaining;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PantryStyle.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _leading(),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PantryStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.location,
                      style: const TextStyle(
                        color: PantryStyle.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                tooltip: 'Item options',
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit?.call();
                  } else if (value == 'use') {
                    onUse?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Item'),
                  ),
                  PopupMenuItem(
                    value: 'use',
                    child: Text('Use Item'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove Item'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8F5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE STOCK',
                  style: TextStyle(
                    color: PantryStyle.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: PantryStyle.primaryDark,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        '$remainingPackages '
                        '${item.packageType}'
                        '${remainingPackages == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: PantryStyle.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  '${_format(item.packageSize)} '
                  '${item.unit} per ${item.packageType}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PantryStyle.inkSoft,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Total remaining: '
                  '${_format(item.amount)} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PantryStyle.ink,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: PantryStyle.inkSoft,
              ),
              const SizedBox(width: 7),
              const Text(
                'Date Purchased',
                style: TextStyle(
                  fontSize: 12,
                  color: PantryStyle.inkSoft,
                ),
              ),
              const Spacer(),
              Text(
                _date(item.purchaseDate),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: PantryStyle.ink,
                ),
              ),
            ],
          ),

          if (onUse != null) ...[
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUse,
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                ),
                label: const Text(
                  'Use Item',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      PantryStyle.primaryDark,
                  foregroundColor: Colors.white,
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
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pantry_provider.dart';
import '../services/crud_service.dart';
import '../theme/pantry_style.dart';

/// Live view of the pantry stored in Firestore (StreamBuilder).
class CloudPantryScreen extends StatefulWidget {
  const CloudPantryScreen({super.key});

  @override
  State<CloudPantryScreen> createState() =>
      _CloudPantryScreenState();
}

class _CloudPantryScreenState extends State<CloudPantryScreen> {
  final CrudService _service = CrudService();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      _service.getItems();

  bool _syncing = false;

  Future<void> _syncNow() async {
    if (_syncing) return;

    final pantry = context.read<PantryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _syncing = true);

    await pantry.syncAllToCloud();

    if (!mounted) return;

    setState(() => _syncing = false);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Pantry synced to the cloud'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _text(num? value) {
    if (value == null) return '0';

    final n = value.toDouble();

    return n == n.roundToDouble()
        ? n.toInt().toString()
        : n.toStringAsFixed(2);
  }

  Widget _thumb(String? url) {
    const fallback = Icon(
      Icons.inventory_2_outlined,
      color: PantryStyle.primaryDark,
    );

    return Container(
      width: 54,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1EB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PantryStyle.surface,
      appBar: AppBar(
        title: const Text(
          'Cloud Pantry',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!_service.isSignedIn) {
            return const Center(
              child: Text('Log in to see your cloud pantry.'),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load cloud data.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PantryStyle.danger),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No items in the cloud yet.\n'
                  'Add a pantry item or tap Sync now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PantryStyle.inkSoft),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final packages = (data['quantity'] as num?)?.toInt() ?? 0;
              final type = data['package_type']?.toString() ?? 'pack';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PantryStyle.cardBorder),
                ),
                child: Row(
                  children: [
                    _thumb(data['image_url'] as String?),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: PantryStyle.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$packages $type'
                            '${packages == 1 ? '' : 's'} · '
                            '${_text(data['package_size'] as num?)} '
                            '${data['unit'] ?? ''} each',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PantryStyle.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['location']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PantryStyle.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
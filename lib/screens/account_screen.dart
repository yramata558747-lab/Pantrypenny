
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_provider.dart';
import '../models/pantry_provider.dart';
import '../models/restock_provider.dart';
import '../theme/pantry_style.dart';

import 'usage_history_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  // DELETE ACCOUNT CONFIRMATION
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete account?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: PantryStyle.ink,
          ),
        ),
        content: const Text(
          'This will permanently delete your local account, '
          'pantry items, grocery list, purchase history, '
          'and usage history. This action cannot be undone.',
          style: TextStyle(
            color: PantryStyle.inkSoft,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete everything',
              style: TextStyle(
                color: PantryStyle.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<PantryProvider>().clearAll();

    if (!context.mounted) return;

    await context.read<RestockProvider>().clearAll();

    if (!context.mounted) return;

    await context.read<AuthProvider>().deleteAccount();

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  // LOCAL DATA INFORMATION
  Future<void> _showLocalData(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Local Data',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: PantryStyle.ink,
          ),
        ),
        content: const Text(
          'Your pantry inventory, Go Grocery list, '
          'purchase history, usage history, and local '
          'account are stored on this device.\n\n'
          'Your data is not uploaded to a server '
          'by these local storage features.',
          style: TextStyle(
            color: PantryStyle.inkSoft,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(
                color: PantryStyle.primaryDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context);
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(
                color: PantryStyle.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TEMPORARY SETTINGS MESSAGE
  void _comingSoon(
    BuildContext context,
    String feature,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // LOG OUT
  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final username =
        auth.currentUsername ?? 'PantryPenny User';

    return Scaffold(
      backgroundColor: PantryStyle.surface,

      body: Column(
        children: [
          // GREEN HEADER
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: PantryStyle.headerGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(26),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  8, 8, 20, 26,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(width: 4),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Manage your PantryPenny profile',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // SCROLLABLE CONTENT
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20, 22, 20, 30,
              ),
              children: [
                // PROFILE CARD
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(22),
                    border: Border.all(
                      color: PantryStyle.cardBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: PantryStyle.primary
                              .withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 38,
                          color: PantryStyle.primaryDark,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        username,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: PantryStyle.ink,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'PantryPenny Member',
                        style: TextStyle(
                          fontSize: 12,
                          color: PantryStyle.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: PantryStyle.inkSoft,
                  ),
                ),

                const SizedBox(height: 12),

                _AccountRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Account Information',
                  subtitle:
                      'View and edit your personal details',
                  onTap: () => _comingSoon(
                    context,
                    'Account Information',
                  ),
                ),

                const SizedBox(height: 12),

                _AccountRow(
                  icon: Icons.history_rounded,
                  title: 'Usage History',
                  subtitle:
                      'View items you have used from your pantry',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const UsageHistoryScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                const Text(
                  'PREFERENCES & STORAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: PantryStyle.inkSoft,
                  ),
                ),

                const SizedBox(height: 12),

                _AccountRow(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  subtitle:
                      'Customize your app preferences',
                  onTap: () => _comingSoon(
                    context,
                    'App Settings',
                  ),
                ),

                const SizedBox(height: 12),

                _AccountRow(
                  icon: Icons.storage_rounded,
                  title: 'Local Data',
                  subtitle:
                      'Manage local storage and account data',
                  onTap: () => _showLocalData(context),
                ),

                const SizedBox(height: 30),

                // LOG OUT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: PantryStyle.danger,
                    ),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: PantryStyle.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      side: const BorderSide(
                        color: PantryStyle.danger,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'PantryPenny • Shop smart. Waste less.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PantryStyle.inkSoft,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// REUSABLE ACCOUNT SETTINGS ROW
class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: PantryStyle.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PantryStyle.primary
                      .withValues(alpha: 0.09),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: PantryStyle.primaryDark,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PantryStyle.ink,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PantryStyle.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: PantryStyle.inkSoft,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

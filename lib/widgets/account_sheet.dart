import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_provider.dart';
import '../models/pantry_provider.dart';
import '../models/restock_provider.dart';
import '../theme/pantry_style.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final pantry = context.read<PantryProvider>();
    final grocery = context.read<RestockProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account AND every item '
          'in your pantry, including the cloud copy. '
          'This can\'t be undone.',
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
              style: TextStyle(color: PantryStyle.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Firebase requires a recent login before deleting an account.
    String? password;

    if (auth.usesPassword) {
      password = await showDialog<String>(
        context: context,
        builder: (_) => const _PasswordDialog(),
      );

      if (password == null || !context.mounted) return;
    }

    final reauth = await auth.reauthenticate(password: password);

    if (!reauth.ok) {
      if (!reauth.cancelled) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              reauth.message ?? 'Unable to verify your identity.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await pantry.clearAll();
    await grocery.clearAll();

    final result = await auth.deleteAccount();

    if (!result.ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Unable to delete.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final username = auth.currentUsername ?? '';
    final email = auth.email ?? '';

    final initial = username.isEmpty
        ? '?'
        : username.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  PantryStyle.primary.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: PantryStyle.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              username,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PantryStyle.ink,
              ),
            ),
            if (email.isNotEmpty && email != username)
              Text(
                email,
                style: const TextStyle(
                  color: PantryStyle.inkSoft,
                  fontSize: 12.5,
                ),
              ),
            const SizedBox(height: 4),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 15,
                  color: PantryStyle.primaryDark,
                ),
                SizedBox(width: 5),
                Text(
                  'Verified account',
                  style: TextStyle(
                    color: PantryStyle.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: PantryStyle.ink,
                ),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: PantryStyle.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: PantryStyle.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(
                  Icons.delete_forever_rounded,
                  color: PantryStyle.danger,
                ),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: PantryStyle.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: PantryStyle.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your password'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: !_visible,
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
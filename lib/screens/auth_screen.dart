import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_provider.dart';
import '../theme/pantry_style.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _createAccount = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _rememberMe = true;
  bool _loading = false;
  bool _needsVerification = false;

  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();

    final auth = context.read<AuthProvider>();

    _rememberMe = auth.rememberMe;
    _emailController.text = auth.rememberedEmail;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  void _changeMode(bool create) {
    setState(() {
      _createAccount = create;
      _passwordController.clear();
      _confirmController.clear();
      _error = null;
      _info = null;
      _needsVerification = false;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_validEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }

    if (_createAccount) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter your name.');
        return;
      }

      if (password.length < 8) {
        setState(() {
          _error = 'Use a password with at least 8 characters.';
        });
        return;
      }

      if (password != _confirmController.text) {
        setState(() => _error = 'Your passwords do not match.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _needsVerification = false;
    });

    final AuthResult result = _createAccount
        ? await auth.register(
            email,
            password,
            displayName: _nameController.text.trim(),
          )
        : await auth.loginWithEmail(
            email,
            password,
            remember: _rememberMe,
          );

    if (!mounted) return;

    setState(() {
      _loading = false;

      if (result.ok && _createAccount) {
        // Account created: go to login and ask for verification.
        _createAccount = false;
        _confirmController.clear();
        _needsVerification = true;
        _info = result.message;
      } else if (!result.ok) {
        _error = result.message;
        _needsVerification = result.needsVerification;
      }
      // On a successful login the auth gate in main.dart
      // switches to the pantry automatically.
    });
  }

  Future<void> _google() async {
    if (_loading) return;

    final auth = context.read<AuthProvider>();

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result =
        await auth.signInWithGoogle(remember: _rememberMe);

    if (!mounted) return;

    setState(() {
      _loading = false;

      if (!result.ok && !result.cancelled) {
        _error = result.message;
      }
    });
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (!mounted || email == null) return;

    final result =
        await context.read<AuthProvider>().sendPasswordReset(email);

    if (!mounted) return;

    setState(() {
      if (result.ok) {
        _info = result.message;
        _error = null;
      } else {
        _error = result.message;
        _info = null;
      }
    });
  }

  Future<void> _resendVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_validEmail(email) || password.isEmpty) {
      setState(() {
        _error = 'Enter your email and password, then tap resend.';
      });
      return;
    }

    setState(() => _loading = true);

    final result = await context
        .read<AuthProvider>()
        .resendVerification(email, password);

    if (!mounted) return;

    setState(() {
      _loading = false;

      if (result.ok) {
        _info = result.message;
        _error = null;
      } else {
        _error = result.message;
      }
    });
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: PantryStyle.cardBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: PantryStyle.primaryDark,
          width: 1.5,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback toggle,
    required TextInputAction action,
    VoidCallback? onDone,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      textInputAction: action,
      onSubmitted: (_) => onDone?.call(),
      decoration: _decoration(
        label: label,
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: toggle,
          icon: Icon(
            visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, Color background, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12.5, height: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: PantryStyle.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
                decoration: const BoxDecoration(
                  gradient: PantryStyle.headerGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'PantryPenny',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your pantry. Your budget. Your way.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(23, 26, 23, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _createAccount
                          ? 'Create Account'
                          : 'Welcome Back',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: PantryStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _createAccount
                          ? 'Sign up with your email. We will send '
                              'a verification link.'
                          : 'Log in to manage your pantry.',
                      style: const TextStyle(
                        color: PantryStyle.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_createAccount) ...[
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          label: 'Name',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: _decoration(
                        label: 'Email',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _passwordField(
                      controller: _passwordController,
                      label: 'Password',
                      visible: _showPassword,
                      toggle: () => setState(
                        () => _showPassword = !_showPassword,
                      ),
                      action: _createAccount
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onDone: _createAccount ? null : _submit,
                    ),
                    if (_createAccount) ...[
                      const SizedBox(height: 14),
                      _passwordField(
                        controller: _confirmController,
                        label: 'Confirm Password',
                        visible: _showConfirm,
                        toggle: () => setState(
                          () => _showConfirm = !_showConfirm,
                        ),
                        action: TextInputAction.done,
                        onDone: _submit,
                      ),
                    ],
                    if (!_createAccount) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: PantryStyle.primaryDark,
                            onChanged: (value) => setState(
                              () => _rememberMe = value ?? true,
                            ),
                          ),
                          const Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 13,
                              color: PantryStyle.ink,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                _loading ? null : _forgotPassword,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: PantryStyle.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_info != null)
                      _banner(
                        _info!,
                        const Color(0xFFE7F1EB),
                        PantryStyle.primaryDark,
                      ),
                    if (_error != null)
                      _banner(
                        _error!,
                        const Color(0xFFFFF0F0),
                        PantryStyle.danger,
                      ),
                    if (_needsVerification && !_createAccount)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              _loading ? null : _resendVerification,
                          icon: const Icon(
                            Icons.forward_to_inbox_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Resend verification email',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: PantryStyle.primaryDark,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: PantryStyle.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 17,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _createAccount
                                    ? 'Create Account'
                                    : 'Log In',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Expanded(
                          child: Divider(color: PantryStyle.cardBorder),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: PantryStyle.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: PantryStyle.cardBorder),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _google,
                        icon: const Icon(
                          Icons.g_mobiledata_rounded,
                          size: 30,
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PantryStyle.ink,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          side: const BorderSide(
                            color: PantryStyle.cardBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => _changeMode(!_createAccount),
                        child: Text(
                          _createAccount
                              ? 'Already have an account? Log In'
                              : 'New here? Create Account',
                          style: const TextStyle(
                            color: PantryStyle.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (auth.legacyUsername != null &&
                        !_createAccount)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Center(
                          child: Text(
                            'PantryPenny now uses email accounts. '
                            'Your pantry data on this device is '
                            'kept - create an account to continue.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: PantryStyle.inkSoft,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState
    extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final email = _controller.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your email and we will send you a link '
            'to reset your password.',
            style: TextStyle(
              color: PantryStyle.inkSoft,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: _error,
            ),
            onSubmitted: (_) => _send(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _send,
          child: const Text('Send link'),
        ),
      ],
    );
  }
}
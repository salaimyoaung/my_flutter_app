import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_routes.dart';

/// Call this before any action that requires the user to be logged in.
///
/// If the user IS logged in → calls [onAuthorized] immediately.
/// If the user is NOT logged in → shows a bottom sheet asking them to log in.
///
/// Usage:
/// ```dart
/// requireLogin(context, onAuthorized: () {
///   context.push(AppRoutes.orderForm, extra: {'product': product});
/// });
/// ```
void requireLogin(
  BuildContext context, {
  required VoidCallback onAuthorized,
  String? message, // optional custom message
}) {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    onAuthorized();
    return;
  }

  // Show login prompt bottom sheet
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LoginPromptSheet(
      message: message,
      onLogin: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.push(AppRoutes.login);
      },
      onSignup: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.push(AppRoutes.signup);
      },
    ),
  );
}

// ─── Bottom Sheet ─────────────────────────────────────────────────────────────

class _LoginPromptSheet extends StatelessWidget {
  final String? message;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const _LoginPromptSheet({
    this.message,
    required this.onLogin,
    required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            'Login လိုအပ်သည်',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          // Message
          Text(
            message ?? 'ဤ feature ကို အသုံးပြုရန် login ဝင်ရောက်ပါ',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 28),

          // Login button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onLogin,
              child: const Text('Login ဝင်မည်'),
            ),
          ),

          const SizedBox(height: 10),

          // Signup button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSignup,
              child: const Text('Account အသစ် ဖွင့်မည်'),
            ),
          ),
        ],
      ),
    );
  }
}

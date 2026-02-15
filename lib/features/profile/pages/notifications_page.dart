import 'package:flutter/material.dart';
import '../../../app_styles.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Notifications", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: const Center(
        child: Text(
          "Notifications မရှိသေးပါ",
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
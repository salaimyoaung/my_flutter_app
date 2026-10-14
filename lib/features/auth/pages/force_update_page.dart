import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/force_update_service.dart';
import '../../../providers/force_update_provider.dart';

class ForceUpdatePage extends ConsumerWidget {
  const ForceUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(forceUpdateProvider).value;
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_rounded, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  'Update လိုအပ်သည်',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  updateState?.message ?? 'ပိုမိုကောင်းမွန်သော ဝန်ဆောင်မှုများ ရရှိရန်အတွက် App အား Update လုပ်ပေးပါရန် မေတ္တာရပ်ခံအပ်ပါသည်။',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final url = updateState?.storeUrl ?? '';
                      await ForceUpdateService.triggerInAppUpdate(url);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Update Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

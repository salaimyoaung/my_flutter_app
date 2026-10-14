import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays "label: value" and copies [value] to clipboard on long-press.
/// Shows a faint copy icon on the right as a discoverability hint.
///
/// Usage:
///   CopyTextRow(label: 'Phone', value: o.buyerPhone)
class CopyTextRow extends StatelessWidget {
  final String label;
  final String value;

  const CopyTextRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$label ကူးယူပြီးပါပြီ ✅'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text('$label: $value')),
            Icon(
              Icons.copy_outlined,
              size: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

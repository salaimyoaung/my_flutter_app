import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ProductActions extends StatelessWidget {
  final bool isOwner;
  final bool isAdmin;
  final bool isSold;
  final VoidCallback onCallSeller;
  final VoidCallback onChatSeller;
  final Future<void> Function() onOrder;
  final VoidCallback onDelete;

  const ProductActions({
    super.key,
    required this.isOwner,
    required this.isAdmin,
    this.isSold = false,
    required this.onCallSeller,
    required this.onChatSeller,
    required this.onOrder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /// 👤 OWNER INFO (UX improvement)
        if (isOwner)...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "ဒါက သင့်ပစ္စည်းဖြစ်သောကြောင့် ဆက်သွယ်မှုများ မလုပ်နိုင်ပါ",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        /// 📞 CALL
        _buildButton(
          context: context,
          icon: Icons.call,
          label: "ရောင်းသူထံ ဖုန်းခေါ်ဆိုရန်",
          color: AppColors.success,
          onPressed: isOwner ? null : onCallSeller,
        ),

        const SizedBox(height: 12),

        /// 💬 MESSAGE
        _buildButton(
          context: context,
          icon: Icons.message,
          label: "Message ပို့ရန်",
          color: Theme.of(context).colorScheme.secondary,
          onPressed: isOwner ? null : onChatSeller,
        ),

        const SizedBox(height: 12),

        /// 🛒 ORDER
        _buildButton(
          context: context,
          icon: Icons.shopping_cart,
          label: "Order တင်မယ်",
          color: scheme.primary,
          onPressed: isOwner ? null : () => onOrder(),
        ),

        /// 🗑 DELETE (Owner only, not sold)
        if ((isOwner || isAdmin) && !isSold) ...[
          const SizedBox(height: 16),
          _buildButton(
            context: context,
            icon: Icons.delete,
            label: "ပစ္စည်းကိုဖျက်မည်",
            color: scheme.error,
            textColor: scheme.onError,
            onPressed: onDelete,
          ),
        ],
      ],
    );
  }

  /// 🔥 reusable button (clean code)
  Widget _buildButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    Color? textColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final isDisabled = onPressed == null;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled
            ? Colors.grey.shade400
            : color,
        foregroundColor: textColor ?? scheme.onPrimary,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: isDisabled ? 0 : 2,
      ),
    );
  }
}
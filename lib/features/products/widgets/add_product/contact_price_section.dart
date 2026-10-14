import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/thousands_separator_input_formatter.dart';

class ContactPriceSection extends StatelessWidget {
  final TextEditingController priceController;
  final TextEditingController originalPriceController;
  final TextEditingController phoneController;

  const ContactPriceSection({
    super.key,
    required this.priceController,
    required this.originalPriceController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsSeparatorInputFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: "အခုရောင်းစျေး",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        /// 🔥 Original Price (NEW)
        TextField(
          controller: originalPriceController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsSeparatorInputFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: "မူရင်းရောင်းစျေး (မထည့်လည်းရ)",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "ဆက်သွယ်ရန် ဖုန်းနံပါတ်",
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';

class DetailsSection extends StatelessWidget {
  final TextEditingController detailController;

  const DetailsSection({
    super.key,
    required this.detailController,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: detailController,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: "အသေးစိတ် / မှတ်ချက် ",
        hintText: "ဥပမာ: 99% အသစ်, Battery 90%, Box ပါ, Warranty ရှိ/မရှိ ...",
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}
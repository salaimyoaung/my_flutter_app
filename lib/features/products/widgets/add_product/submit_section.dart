import 'package:flutter/material.dart';

class SubmitSection extends StatelessWidget {
  final bool isUploading;
  final bool isImageUploading;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const SubmitSection({
    super.key,
    required this.isUploading,
    required this.isImageUploading,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (isUploading) {
      return const CircularProgressIndicator();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isUploading || isImageUploading || !canSubmit)
            ? null
            : onSubmit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          "တင်မည်",
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
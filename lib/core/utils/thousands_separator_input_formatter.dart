import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Strip all non-digits (including commas)
    String stripped = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (stripped.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse to int
    int? value = int.tryParse(stripped);
    if (value == null) return oldValue;

    // Format with commas
    String formatted = _formatter.format(value);

    // Keep cursor at the end or calculate offset if needed. 
    // Simple implementation: move cursor to end.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatString(String value) {
    if (value.isEmpty) return '';
    // Strip decimals and non-digits for formatting
    String stripped = value.split('.').first.replaceAll(RegExp(r'[^\d]'), '');
    int? parsed = int.tryParse(stripped);
    if (parsed == null) return value;
    return _formatter.format(parsed);
  }
}

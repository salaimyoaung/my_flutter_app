class ImeiValidator {
  static bool isValid(String imei) {
    if (imei.length != 15) return false;
    if (!RegExp(r'^\d{15}$').hasMatch(imei)) return false;

    int sum = 0;

    for (int i = 0; i < 14; i++) {
      int digit = int.parse(imei[i]);

      if (i % 2 == 1) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
    }

    int checkDigit = (10 - (sum % 10)) % 10;

    return checkDigit == int.parse(imei[14]);
  }
}
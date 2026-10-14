class ImeiValidator {
  /// Check if IMEI is valid (15 digits + Luhn check)
  static bool isValid(String imei) {

    // remove spaces
    imei = imei.replaceAll(" ", "");

    // must be 15 digits
    if (imei.length != 15) {
      return false;
    }

    // must be numeric
    if (!RegExp(r'^[0-9]+$').hasMatch(imei)) {
      return false;
    }

    int sum = 0;

    for (int i = 0; i < imei.length; i++) {

      int digit = int.parse(imei[i]);

      // double every second digit
      if (i % 2 == 1) {
        digit *= 2;

        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
    }

    // Luhn check
    return sum % 10 == 0;
  }
}
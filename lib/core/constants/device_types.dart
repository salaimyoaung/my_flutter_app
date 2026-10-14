class DeviceTypes {
  static const String androidPhone = 'android_phone';
  static const String androidTablet = 'android_tablet';
  static const String iphone = 'iphone';
  static const String ipad = 'ipad';

  static bool isValid(String raw) => {
    androidPhone,
    androidTablet,
    iphone,
    ipad,
  }.contains(raw);

  static String safe(String raw) => isValid(raw) ? raw : androidPhone;
}

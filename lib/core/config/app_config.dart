/// App-level configuration values injected at build time via --dart-define.
///
/// Usage (build / run):
///   flutter run  --dart-define=RECAPTCHA_SITE_KEY=your_key_here
///   flutter build apk --dart-define=RECAPTCHA_SITE_KEY=your_key_here
///
/// In CI/CD, set RECAPTCHA_SITE_KEY as a secret environment variable and
/// pass it with --dart-define=RECAPTCHA_SITE_KEY=$RECAPTCHA_SITE_KEY.
///
/// NEVER commit the actual key to source control.
class AppConfig {
  AppConfig._();

  /// Firebase App Check reCAPTCHA v3 site key (web only).
  /// Injected via --dart-define=RECAPTCHA_SITE_KEY=...
  static const String reCaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '', // empty → AppCheck activation will fail gracefully on web
  );

  /// Flag to prevent auto sign-out when the user is actively deleting their own account.
  static bool isDeletingAccount = false;
}

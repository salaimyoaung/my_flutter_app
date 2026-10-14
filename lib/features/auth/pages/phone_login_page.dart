import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sigmamoby/core/router/app_routes.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/data/services/notification_service.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  // ── State ────────────────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _otpFocus  = FocusNode();

  bool _isLoading   = false;
  bool _codeSent    = false;
  String? _verificationId;
  int? _resendToken;

  // Countdown for resend
  int _secondsLeft = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Myanmar phone → E.164  e.g. "09xxxxxxx" → "+959xxxxxxx"
  String _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('09')) return '+95${digits.substring(1)}';
    if (digits.startsWith('9'))  return '+95$digits';
    return '+$digits';
  }

  void _startCountdown() {
    setState(() => _secondsLeft = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secondsLeft--);
      return _secondsLeft > 0;
    });
  }

  // ── Send OTP ─────────────────────────────────────────────────────────────────
  Future<void> _sendOtp({bool isResend = false}) async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) { _snack('ဖုန်းနံပါတ် ထည့်ပါ'); return; }

    final e164 = _toE164(phone);
    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164,
      forceResendingToken: isResend ? _resendToken : null,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential cred) async {
        // Android auto-retrieval
        await _signInWithCredential(cred);
      },

      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _snack('OTP ပို့မရပါ: ${e.message ?? e.code}');
      },

      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _isLoading      = false;
          _codeSent       = true;
          _verificationId = verificationId;
          _resendToken    = resendToken;
        });
        _startCountdown();
        _snack('OTP ကို $e164 သို့ ပို့ပေးလိုက်ပါပြီ');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) FocusScope.of(context).requestFocus(_otpFocus);
        });
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) { _snack('OTP 6 လုံး ထည့်ပါ'); return; }
    if (_verificationId == null) { _snack('ဦးစွာ OTP ထပ်တောင်းပါ'); return; }

    setState(() => _isLoading = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(e.code == 'invalid-verification-code'
          ? 'OTP မှားနေပါတယ်'
          : 'Error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Error: $e');
    }
  }

  // ── Post sign-in ─────────────────────────────────────────────────────────────
  Future<void> _signInWithCredential(PhoneAuthCredential cred) async {
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final user   = result.user!;
      await _handleSignedInUser(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Error: ${e.message ?? e.code}');
    }
  }

  Future<void> _handleSignedInUser(User user) async {
    final db     = FirebaseFirestore.instance;
    final docRef = db.collection('users').doc(user.uid);
    final snap   = await docRef.get();

    if (snap.data()?['isBanned'] == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _snack('ဒီအကောင့်ကို ပိတ်ထားပါတယ်');
      setState(() => _isLoading = false);
      return;
    }

    if (!snap.exists) {
      // New user — auto-create Firestore doc
      final phone = user.phoneNumber ?? '';
      await docRef.set({
        'uid':          user.uid,
        'name':         'User',
        'email':        '',
        'phone':        phone,
        'profileImage': '',
        'coverImage':   '',
        'shopCity':     '',
        'shopAddress':  '',
        'isOnline':     true,
        'isBanned':     false,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
    }

    NotificationService.saveTokenToUser().catchError(
      (e) { if (kDebugMode) debugPrint('FCM token save failed: $e'); },
    );

    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const BrandAppBar(title: 'ဖုန်းနံပါတ်နဲ့ Login ဝင်မည်'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Phone field ──────────────────────────────────────────
                Text('ဖုန်းနံပါတ်', style: textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  enabled: !_codeSent && !_isLoading,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '09xxxxxxxxx',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixText: '+95',
                    suffixStyle: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                    helperText: 'Myanmar ဖုန်းနံပါတ် (09xxx) ထည့်ပါ — +95 အလိုအလျောက် ထည့်သွင်းမည်',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: scheme.surface,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Send OTP button ──────────────────────────────────────
                if (!_codeSent) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('OTP ပေးပို့မည်'),
                    ),
                  ),
                ],

                // ── OTP field (after code sent) ──────────────────────────
                if (_codeSent) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sms_outlined, size: 16,
                            color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'OTP ကို ${_toE164(_phoneCtrl.text.trim())} သို့ ပို့ပေးလိုက်ပါပြီ',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text('OTP ကုဒ်', style: textTheme.labelMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otpCtrl,
                    focusNode: _otpFocus,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                        letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '______',
                      hintStyle: textTheme.headlineSmall?.copyWith(
                          letterSpacing: 8, color: scheme.outlineVariant),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: scheme.surface,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('အတည်ပြုမည်'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Resend
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            'OTP ထပ်တောင်းရန် ${_secondsLeft}s စောင့်ပါ',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          )
                        : TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => _sendOtp(isResend: true),
                            child: const Text('OTP ထပ်တောင်းမည်'),
                          ),
                  ),

                  // Change number
                  Center(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _codeSent = false;
                                _otpCtrl.clear();
                                _verificationId = null;
                              }),
                      child: Text(
                        'ဖုန်းနံပါတ် ပြောင်းမည်',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

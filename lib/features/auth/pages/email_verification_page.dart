import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/services/notification_service.dart';

/// Shown after signup and whenever a signed-in user is not yet email-verified.
/// Polls every 5 seconds and auto-advances once verification is confirmed.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  Timer? _timer;
  bool _isResending = false;
  bool _justResent = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      try {
        // ✅ Wrap in try-catch to prevent crashes when network is lost
        await user.reload();
        if (user.emailVerified && mounted) {
          _timer?.cancel();
          if (mounted) context.go(AppRoutes.home);
        }
      } catch (e) {
        // network failure ဖြစ်ရင် ဘာမှမလုပ်ဘဲ နောက် ၅ စက္ကန့်နေမှ ပြန်စမ်းခိုင်းတာပါ
        if (kDebugMode) debugPrint("[EmailVerification] Polling error: $e");
      }
    });
  }

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isResending = true);
    try {
      await user.sendEmailVerification();
      if (mounted) {
        setState(() => _justResent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification link ပို့ပြီးပါပြီ။ Inbox ကို စစ်ဆေးပါ')),
        );
      }
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) setState(() => _justResent = false);
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Email ပို့မရပါ';
        if (e.code == 'too-many-requests') {
          msg = 'ခဏခဏ ပို့လွန်းလို့ ခေတ္တ block ခံထားရပါတယ်။ နောက် ၁၅ မိနစ်လောက်နေမှ ပြန်ကြိုးစားပါ။';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await NotificationService.onLogout();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go(AppRoutes.home);
  }



  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Email ကို Verify လုပ်ပါ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'Verification link ကို ',
                  children: [
                    TextSpan(
                      text: email,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const TextSpan(text: ' ထံသို့ ပို့ပေးထားပါသည်။'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Link ကို နှိပ်ပြီးပါက ဤနေရာသို့ ပြန်လာပါ။ အလိုအလျောက် ရှေ့ဆက်သွားပါမည်။',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              if (_justResent)
                const Text(
                  '✅ အသစ်ထပ်ပို့ပြီးပါပြီ (၁ မိနစ်နေမှ ပြန်ပို့နိုင်ပါမည်)',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResending ? null : _resendEmail,
                    icon: _isResending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('Email ပြန်ပို့မည်'),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _signOut,
                child: const Text('Email မှားနေပါသလား? Sign Out လုပ်ရန်'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

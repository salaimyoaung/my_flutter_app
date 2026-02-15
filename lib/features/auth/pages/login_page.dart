import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import 'package:realproject/data/services/fcm_service.dart';
import '../../../app_styles.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final e = email.trim();
    return e.contains('@') && e.contains('.');
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Email မမှန်ပါ";
      case 'user-disabled':
        return "ဒီအကောင့်ကို ပိတ်ထားပါတယ်";
      case 'user-not-found':
        return "ဒီ Email နဲ့ အကောင့်မတွေ့ပါ";
      case 'wrong-password':
        return "Password မှားနေပါတယ်";
      case 'invalid-credential':
        return "Email သို့မဟုတ် Password မှားနေပါသည်";
      case 'too-many-requests':
        return "ကြိုးစားမှုများလွန်းလို့ ခဏနားပြီး ပြန်လုပ်ပါ";
      default:
        return "Login မအောင်မြင်ပါ: ${e.message ?? e.code}";
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email နဲ့ Password ဖြည့်ပါ")),
      );
      return;
    }
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email မမှန်ပါ")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ Token save ကို login အောင်မြင်မှုနဲ့ မချိတ် (optional try/catch)
      try {
        await saveFcmTokenForCurrentUser();
      } catch (e) {
        debugPrint("FCM token save failed: $e");
      }

      if (!mounted) return;

      context.go(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email သို့မဟုတ် Password မှားနေပါသည်")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password ပြန်ချရန် Email အရင်ရိုက်ထည့်ပါ")),
      );
      return;
    }
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email မမှန်ပါ")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link ကို Email ထဲသို့ ပို့ပေးလိုက်ပါပြီ")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Login ဝင်ရန်", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Text(
              "ကြိုဆိုပါတယ်",
              style: AppTextStyles.heading(context).copyWith(fontSize: 24),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: "Password",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetPassword,
                child: Text(
                  "Password မေ့နေပါသလား?",
                  style: TextStyle(color: scheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _login,
                child: const Text("Login ဝင်မည်"),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("အကောင့်မရှိသေးဘူးလား?"),
                TextButton(
                  onPressed: () {
                    context.go(AppRoutes.signup);
                  },
                  child: Text("Signup", style: TextStyle(color: scheme.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import 'package:sigmamoby/data/services/notification_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email.trim());
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("အချက်အလက် ပြည့်စုံအောင် ဖြည့်ပါ")),
      );
      return;
    }
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email မမှန်ပါ")),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password က အနည်းဆုံး ၈ လုံး ရှိရပါမည်")),
      );
      return;
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password မှာ အကြီးစာလုံး (A-Z) အနည်းဆုံး ၁ လုံး ပါရမည်")),
      );
      return;
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password မှာ နံပါတ် (0-9) အနည်းဆုံး ၁ လုံး ပါရမည်")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Check if name is already taken by a verified seller
      final nameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: name)
          .where('isVerified', isEqualTo: true)
          .limit(1)
          .get();

      if (nameCheck.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ဤအမည်မှာ အတည်ပြုပြီးသား Seller တစ်ဦး အသုံးပြုထားပြီးဖြစ်ပါသည်။ အခြားအမည်တစ်ခု ရွေးချယ်ပေးပါ။")),
          );
        }
        return;
      }

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("User create မအောင်မြင်ပါ");

      // 1) users doc create/update
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'profileImage': '',

          // 🔥 Marketplace fields
          'role': 'user',
          'isVerified': false,
          'totalSales': 0,
          'totalOrders': 0,
          'rating': 0.0,
          'coverImage': '',
          'shopCity': '',
          'shopAddress': '',
          'isOnline': true,
          'isBanned': false,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2) Send email verification
      try {
        await user.sendEmailVerification();
      } catch (e) {
        if (kDebugMode) debugPrint("sendEmailVerification error: $e");
      }

      // 3) ✅ Token save ကို signup အောင်မြင်မှုနဲ့ မချိတ် (optional try/catch)
      // NotificationService.saveTokenToUser() သုံးသည် — update() ဖြင့် Firestore rules နဲ့ consistent
      try {
        await NotificationService.saveTokenToUser();
      } catch (e) {
        if (kDebugMode) debugPrint("FCM token save failed: $e");
      }

      if (!mounted) return;

      // Redirect to email verification page — router will enforce this anyway,
      // but navigating explicitly gives immediate feedback.
      context.go(AppRoutes.emailVerification);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("အကောင့်ဖွင့်ပြီးပါပြီ — Email verify လုပ်ပါ")),
      );
    } on FirebaseAuthException catch (e) {
      String message = "အမှားတစ်ခုရှိနေပါသည်";
      bool isExistingGoogleAccount = false;
      if (e.code == 'weak-password') {
        message = "Password က အနည်းဆုံး ၈ လုံး ရှိရပါမည်";
      } else if (e.code == 'email-already-in-use') {
        message = "ဒီ Email ဖြင့် အကောင့်ရှိပြီးသားဖြစ်နေပါသည် (Google ဖြင့် ဝင်ထားသူဖြစ်ပါက Login မျက်နှာပြင်မှ Google ဖြင့် ဝင်ပါ)";
        isExistingGoogleAccount = true;
      } else if (e.code == 'invalid-email') {
        message = "Email မမှန်ပါ";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: "အကောင့်အသစ်ဖွင့်ရန်"),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxForm),
            child: Column(
              children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "ရောင်းသူအမည် (Profile Name)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
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
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "ဖုန်းနံပါတ်",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: "Password (အနည်းဆုံး ၈ လုံး)",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _signUp,
                      child: Text(
                        "အကောင့်ဖွင့်မည်",
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("အကောင့်ရှိပြီးသားလား?", style: textTheme.bodyMedium),
                TextButton(
                  onPressed: () {
                    context.go(AppRoutes.login);
                  },
                  child: Text(
                    "Login ဝင်ရန်",
                    style: textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

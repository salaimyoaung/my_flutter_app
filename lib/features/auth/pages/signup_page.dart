import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import 'package:realproject/data/services/fcm_service.dart';
import '../../../app_styles.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final e = email.trim();
    return e.contains('@') && e.contains('.');
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
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password က အနည်းဆုံး ၆ လုံး ရှိရပါမည်")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2) ✅ Token save ကို signup အောင်မြင်မှုနဲ့ မချိတ် (optional try/catch)
      try {
        await saveFcmTokenForCurrentUser();
      } catch (e) {
        debugPrint("FCM token save failed: $e");
      }

      if (!mounted) return;

      context.go(AppRoutes.home);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("အကောင့်ဖွင့်ပြီးပါပြီ")),
      );
    } on FirebaseAuthException catch (e) {
      String message = "အမှားတစ်ခုရှိနေပါသည်";
      if (e.code == 'weak-password') {
        message = "Password က အနည်းဆုံး ၆ လုံး ရှိရပါမည်";
      } else if (e.code == 'email-already-in-use') {
        message = "ဒီ Email နဲ့ အကောင့်ရှိပြီးသားဖြစ်နေပါသည်";
      } else if (e.code == 'invalid-email') {
        message = "Email မမှန်ပါ";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("အကောင့်အသစ်ဖွင့်ရန်", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
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
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password (အနည်းဆုံး ၆ လုံး)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
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
                onPressed: _signUp,
                child: const Text("အကောင့်ဖွင့်မည်"),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("အကောင့်ရှိပြီးသားလား?"),
                TextButton(
                  onPressed: () {
                    context.go(AppRoutes.login);
                  },
                  child: Text(
                    "Login ဝင်ရန်",
                    style: TextStyle(color: scheme.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

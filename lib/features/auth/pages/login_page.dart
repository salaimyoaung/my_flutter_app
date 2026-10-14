import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_responsive.dart';
import 'package:sigmamoby/data/services/notification_service.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

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
    return RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email.trim());
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Email မမှန်ပါ";
      case 'user-disabled':
        return "ဒီအကောင့်ကို ပိတ်ထားပါတယ်";
      case 'user-not-found':
        return "ဒီ Email နဲ့ အကောင့်မတွေ့ပါ (Google ဖြင့် ဖွင့်ထားသူဖြစ်ပါက အောက်ပါ Google ခလုတ်ကို သုံးပါ)";
      case 'wrong-password':
        return "Password မှားနေပါတယ်";
      case 'invalid-credential':
        return "Email သို့မဟုတ် Password မှားနေပါသည် (Google ဖြင့် ဖွင့်ထားသူဖြစ်ပါက အောက်ပါ Google ခလုတ်ကို သုံးပါ)";
      case 'too-many-requests':
        return "ကြိုးစားမှုများလွန်းလို့ ခဏနားပြီး ပြန်လုပ်ပါ";
      default:
        return "Login မအောင်မြင်ပါ: ${e.message ?? e.code}";
    }
  }

  // ── Shared post-auth handler (ban check + FCM + create doc if new) ──────────
  Future<void> _handleSignedInUser(User user) async {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('users').doc(user.uid);
    final snap = await docRef.get();

    // Ban check
    if (snap.data()?['isBanned'] == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ဒီအကောင့်ကို ပိတ်ထားပါတယ်")),
      );
      return;
    }
    // Auto-create Firestore doc for new social-login users
    if (!snap.exists) {
      await docRef.set({
        'uid':          user.uid,
        'name':         user.displayName ?? 'User',
        'email':        user.email ?? '',
        'phone':        '',
        'profileImage': user.photoURL ?? '',
        'coverImage':   '',
        'shopCity':     '',
        'shopAddress':  '',
        'role':         'user',
        'isOnline':     true,
        'isBanned':     false,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
    }

    NotificationService.saveTokenToUser().catchError(
          (e) { if (kDebugMode) debugPrint("FCM token save failed: $e"); },
    );

    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  // ── Email / Password ─────────────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

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
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _handleSignedInUser(cred.user!);
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

  // ── Google Sign-In ───────────────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    if (kDebugMode) print("Google Sign-In started");
    setState(() => _isLoading = true);
    try {
      if (kDebugMode) print("Initializing GoogleSignIn...");
      await GoogleSignIn.instance.initialize();
      if (kDebugMode) print("Authenticating...");
      late final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
        if (kDebugMode) print("Google Auth Success: ${googleUser.email}");
      } catch (e) {
        if (kDebugMode) print("Google Auth Error (authenticate): $e");
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = googleUser.authentication;
      if (kDebugMode) print("ID Token: ${googleAuth.idToken != null}");
      
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      if (kDebugMode) print("Signing in to Firebase...");
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (kDebugMode) print("Firebase Auth Success: ${cred.user?.uid}");
      await _handleSignedInUser(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print("Firebase Auth Error: ${e.code} - ${e.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e))),
      );
    } catch (e) {
      if (kDebugMode) print("General Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Login မအောင်မြင်ပါ: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Password Reset ───────────────────────────────────────────────────────────
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: "Login ဝင်ရန်"),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxForm),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Text("ကြိုဆိုပါတယ်", style: textTheme.headlineSmall),
                const SizedBox(height: 30),

                // ── Email field ──────────────────────────────────────────
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

                // ── Password field ───────────────────────────────────────
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
                      style: textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Login button ─────────────────────────────────────────
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
                    onPressed: _login,
                    child: const Text("Login ဝင်မည်"),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Divider ──────────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "သို့မဟုတ်",
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Google button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: Image.asset(
                      'assets/icons/google_logo.png',
                      height: 22,
                      errorBuilder: (_, _, _) =>
                      const Icon(Icons.g_mobiledata, size: 22),
                    ),
                    label: const Text("Google နဲ့ Login ဝင်မည်"),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Sign up ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("အကောင့်မရှိသေးဘူးလား?", style: textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.signup),
                      child: Text(
                        "Signup",
                        style: textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),

                // ── Guest browse ─────────────────────────────────────────
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(
                    "Login မဝင်ဘဲ ကြည့်ရှုမည်",
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';


/// Splash page — GoRouter redirect logic က auth state ကို handle လုပ်သောကြောင့်
/// ဒီ page မှ navigation မလုပ်ရ (redirect က auto navigate လုပ်မည်)။
/// Force update check ကိုသာ ဒီ page မှ run ပါ။
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

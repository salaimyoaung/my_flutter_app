import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/pages/login_page.dart';
import '../../products/pages/seller_wall_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ✅ StreamBuilder ဖြင့် auth state ကို listen လုပ်သည် —
    // PageView ထဲမှာ ရှိသောကြောင့် build တစ်ကြိမ်သာ ဖြစ်ပြီး
    // currentUser ကို once-read မလုပ်ရ၊ stream ဖြင့် rebuild ဖြစ်ရမည်။
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          // ✅ Directly show LoginPage instead of an intermediate prompt
          return const LoginPage();
        }

        return SellerWallPage(
          sellerId: user.uid,
          sellerName: user.displayName ?? '',
        );
      },
    );
  }
}

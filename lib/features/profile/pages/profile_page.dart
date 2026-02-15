import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/pages/login_page.dart';
import '../../products/pages/seller_wall_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // login မဝင်ရသေးရင် login page ပြ
      return const LoginPage();
    }

    // ✅ Profile = My Listings only (current user wall)
    return SellerWallPage(
      sellerId: user.uid,
      sellerName: "My Shop",
    );
  }
}
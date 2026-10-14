import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../data/services/admin_access_service.dart';
import '../../../../data/services/notification_service.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';

class SellerHeader extends StatelessWidget {
  final String sellerId;

  const SellerHeader({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox(height: 250);
        }

        final data = snap.data!.data()!;

        final name = data['name'] ?? "Shop";
        final profile = data['profileImage'] ?? "";
        final cover = data['coverImage'] ?? "";
        final address = data['shopAddress'] ?? "";
        final city = data['shopCity'] ?? "";
        final isVerified = data['isVerified'] == true;

        /// Member since
        String memberText = "";
        final ts = data['createdAt'];

        if (ts is Timestamp) {
          final date = ts.toDate();

          const months = [
            "January","February","March","April","May","June",
            "July","August","September","October","November","December"
          ];

          memberText = "Member since ${months[date.month - 1]} ${date.year}";
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final isOwner = currentUid == sellerId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// COVER
            Stack(
              clipBehavior: Clip.none,
              children: [

                Container(
                  height: 150,
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest,
                  child: cover.isNotEmpty
                      ? AppNetworkImage(
                          cover,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        )
                      : const Icon(Icons.image),
                ),

                /// AVATAR
                Positioned(
                  left: 16,
                  bottom: -35,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.black,
                    backgroundImage:
                    profile.isNotEmpty ? NetworkImage(profile) : null,
                    child: profile.isEmpty
                        ? const Icon(Icons.store, size: 40)
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            /// NAME
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVerified) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.verified,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            /// EDIT PROFILE + MESSAGES + MY REQUESTS + LOGOUT
            if (isOwner)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Row(
                  children: [
                    // ── Profile ပြင်မည် ──────────────────────────
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        context.push(
                          AppRoutes.editProfile,
                          extra: {
                            'currentName': name,
                            'currentPhone': data['phone'] ?? '',
                            'currentCoverImage': cover,
                            'currentProfileImage': profile,
                          },
                        );
                      },
                      icon: Icon(Icons.edit, size: 16, color: scheme.primary),
                      label: Text(
                        "Edit Profile",
                        style: TextStyle(color: scheme.primary),
                      ),
                    ),
                    // ── Logout ───────────────────────────────────
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Logout"),
                            content: const Text("ထွက်မလား?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("မထွက်ဘူး"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  if (uid != null) {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .update({
                                        'isOnline': false,
                                        'lastSeen': FieldValue.serverTimestamp(),
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      });
                                    } catch (_) {}
                                  }
                                  AdminAccessService.instance.clear();
                                  await NotificationService.onLogout();
                                  try {
                                    await GoogleSignIn.instance.signOut();
                                  } catch (_) {}
                                  if (!context.mounted) return;
                                  context.go(AppRoutes.home);
                                  await FirebaseAuth.instance.signOut();
                                },
                                child: Text(
                                  "ထွက်မယ်",
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Icon(Icons.logout, size: 16, color: Theme.of(context).colorScheme.error),
                      label: Text(
                        "Logout",
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            /// LOCATION
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 16),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on, size: 14),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text("$address ($city)"),
                ),
                const SizedBox(width: 16),
              ],
            ),

            const SizedBox(height: 4),

            /// MEMBER DATE
            if (memberText.isNotEmpty)
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text(memberText)),
                  const SizedBox(width: 16),
                ],
              ),

            const SizedBox(height: 4),

            /// SALES COMPLETED — read from users doc (cached field)
            Builder(builder: (context) {
              final count = ((data['totalSales'] ?? data['completedSales'] ?? 0) as num).toInt();
              if (count <= 0) return const SizedBox.shrink();
              return Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.check_circle_outline, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: Text('$count Sales Completed')),
                  const SizedBox(width: 16),
                ],
              );
            }),

            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/brand_app_bar.dart';

class AdminBannedUsersPage extends StatelessWidget {
  const AdminBannedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(title: 'Banned Users'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('isBanned', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Banned user မရှိပါ'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final uid = docs[i].id;
              final name = (d['name'] ?? uid).toString();
              final email = (d['email'] ?? '').toString();
              final profileImage = (d['profileImage'] ?? '').toString();

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  leading: GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.sellerWallPath(uid),
                      extra: {'sellerId': uid, 'sellerName': name},
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: profileImage.isNotEmpty
                          ? NetworkImage(profileImage)
                          : null,
                      child: profileImage.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                  ),
                  title: GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.sellerWallPath(uid),
                      extra: {'sellerId': uid, 'sellerName': name},
                    ),
                    child: Text(
                      name,
                      style: textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  subtitle: email.isNotEmpty ? Text(email) : null,
                  trailing: TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Unban user?'),
                          content: Text('$name ကို unban လုပ်မည်။'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Unban'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update({'isBanned': false});

                      // Reactivate all their products
                      final productSnap = await FirebaseFirestore.instance
                          .collection('products')
                          .where('sellerId', isEqualTo: uid)
                          .get();
                      final batch = FirebaseFirestore.instance.batch();
                      for (final p in productSnap.docs) {
                        batch.update(p.reference, {'active': true});
                      }
                      await batch.commit();

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name unbanned')),
                      );
                    },
                    icon: const Icon(Icons.lock_open_outlined, size: 16),
                    label: const Text('Unban'),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.tertiary),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

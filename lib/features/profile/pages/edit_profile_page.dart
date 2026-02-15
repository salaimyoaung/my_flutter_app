import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app_styles.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentPhone;

  final String currentCoverImage;
  final String currentProfileImage;

  const EditProfilePage({
    super.key,
    required this.currentName,
    required this.currentPhone,
    this.currentCoverImage = '',
    this.currentProfileImage = '',
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  final _picker = ImagePicker();

  String _profileUrl = '';
  String _coverUrl = '';

  File? _profileFile;
  File? _coverFile;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);

    _profileUrl = widget.currentProfileImage;
    _coverUrl = widget.currentCoverImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() => _profileFile = File(picked.path));
  }

  Future<void> _pickCoverImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _coverFile = File(picked.path));
  }

  Future<String> _uploadToStorage({
    required File file,
    required String path, // e.g. "profiles/{uid}.jpg"
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("နာမည်/ဆိုင်အမည် ထည့်ပေးပါ")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login မဝင်ထားပါ")),
          );
        }
        return;
      }

      // 1) upload selected images (if any)
      if (_profileFile != null) {
        _profileUrl = await _uploadToStorage(
          file: _profileFile!,
          path: 'profiles/${user.uid}.jpg',
        );
      }

      if (_coverFile != null) {
        _coverUrl = await _uploadToStorage(
          file: _coverFile!,
          path: 'covers/${user.uid}.jpg',
        );
      }

      // 2) update firestore
      final update = <String, dynamic>{
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_profileUrl.trim().isNotEmpty) update['profileImage'] = _profileUrl.trim();
      if (_coverUrl.trim().isNotEmpty) update['coverImage'] = _coverUrl.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(update, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile ပြင်ဆင်ပြီးပါပြီ")),
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
        title: Text("Profile ပြင်ဆင်ရန်", style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // COVER PREVIEW + PICK BUTTON
            Container(
              height: 140,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: _coverFile != null
                  ? Image.file(_coverFile!, fit: BoxFit.cover)
                  : (_coverUrl.trim().isNotEmpty
                  ? Image.network(
                _coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
                ),
              )
                  : Center(child: Icon(Icons.photo, color: scheme.onSurfaceVariant))),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.photo),
              label: const Text("Cover ပုံရွေးမည်"),
            ),

            const SizedBox(height: 18),

            // PROFILE PREVIEW + PICK BUTTON
            CircleAvatar(
              radius: 44,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: _profileFile != null
                  ? FileImage(_profileFile!)
                  : (_profileUrl.trim().isNotEmpty ? NetworkImage(_profileUrl) as ImageProvider : null),
              child: (_profileFile == null && _profileUrl.trim().isEmpty)
                  ? Icon(Icons.store, size: 44, color: scheme.primary)
                  : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickProfileImage,
              icon: const Icon(Icons.image),
              label: const Text("Profile ပုံရွေးမည်"),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "ဆိုင်အမည် / ရောင်းသူအမည်",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
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
            const SizedBox(height: 24),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _updateProfile,
              child: const Text("ပြင်ဆင်မှုများ သိမ်းမည်"),
            ),
          ],
        ),
      ),
    );
  }
}
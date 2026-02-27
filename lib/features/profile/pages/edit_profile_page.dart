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
  late final TextEditingController _shopAddressController;
  late final TextEditingController _shopCityController;

  final List<String> majorCities = [
    "Yangon",
    "Mandalay",
    "Naypyidaw",
    "Bago",
    "Taungoo",
    "Pyay",
    "Mawlamyine",
    "Pathein",
    "Magway",
    "Myitkyina",
  ];

  final _picker = ImagePicker();

  String _profileUrl = '';
  String _coverUrl = '';
  String? _selectedCity;

  File? _profileFile;
  File? _coverFile;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _shopAddressController = TextEditingController();
    _shopCityController = TextEditingController();

    _profileUrl = widget.currentProfileImage;
    _coverUrl = widget.currentCoverImage;

    _loadExistingLocation();
  }

  Future<void> _loadExistingLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final data = doc.data();
    if (data == null) return;

    _shopAddressController.text =
        (data['shopAddress'] ?? '').toString();
    _shopCityController.text =
        (data['shopCity'] ?? '').toString();
    _selectedCity = (data['shopCity'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _shopAddressController.dispose();
    _shopCityController.dispose();
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
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(file, metadata);
    return await ref.getDownloadURL();
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _shopAddressController.text.trim();
    final city = _shopCityController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("နာမည်/ဆိုင်အမည် ထည့်ပေးပါ")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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

      final update = <String, dynamic>{
        'name': name,
        'phone': phone,
        'shopAddress': _shopAddressController.text.trim(),
        'shopCity': _selectedCity ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_profileUrl.isNotEmpty) update['profileImage'] = _profileUrl;
      if (_coverUrl.isNotEmpty) update['coverImage'] = _coverUrl;

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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
        title: Text("Profile ပြင်ဆင်ရန်",
            style: AppTextStyles.heading(context)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // ✅ COVER PREVIEW
            Container(
              height: 140,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _coverFile != null
                  ? Image.file(_coverFile!, fit: BoxFit.cover)
                  : (_coverUrl.isNotEmpty
                  ? Image.network(_coverUrl, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.photo))),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.photo),
              label: const Text("Cover ပုံရွေးမည်"),
            ),

            const SizedBox(height: 20),

            // ✅ PROFILE PREVIEW
            CircleAvatar(
              radius: 45,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: _profileFile != null
                  ? FileImage(_profileFile!)
                  : (_profileUrl.isNotEmpty
                  ? NetworkImage(_profileUrl)
                  : null) as ImageProvider?,
              child: (_profileFile == null && _profileUrl.isEmpty)
                  ? Icon(Icons.store, size: 40, color: scheme.primary)
                  : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickProfileImage,
              icon: const Icon(Icons.image),
              label: const Text("Profile ပုံရွေးမည်"),
            ),

            const SizedBox(height: 20),

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
            const SizedBox(height: 15),

            TextField(
              controller: _shopAddressController,
              decoration: const InputDecoration(
                labelText: "ဆိုင်လိပ်စာ",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedCity?.isEmpty == true ? null : _selectedCity,
              decoration: const InputDecoration(
                labelText: "မြို့",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
              items: majorCities
                  .map((city) => DropdownMenuItem(
                value: city,
                child: Text(city),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCity = value;
                });
              },
            ),
            const SizedBox(height: 24),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("ပြင်ဆင်မှုများ သိမ်းမည်"),
            ),
          ],
        ),
      ),
    );
  }
}
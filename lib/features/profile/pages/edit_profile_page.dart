import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/notification_helper.dart';
import 'package:sigmamoby/core/config/app_config.dart';
import 'package:sigmamoby/core/router/app_routes.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';
import 'package:sigmamoby/core/widgets/app_network_image.dart';
import 'package:sigmamoby/core/widgets/city_picker_sheet.dart';

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

  // ✅ Removed hardcoded city list — now uses CityPickerSheet (Firestore-driven)

  final _picker = ImagePicker();

  String _profileUrl = '';
  String _coverUrl = '';
  String? _selectedCity;

  File? _profileFile;
  File? _coverFile;
  File? _verificationFile;

  bool _isLoading = false;
  bool _isUploadingDoc = false;
  
  bool _isVerified = false;
  String _verificationDocUrl = '';

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

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    _shopAddressController.text = (data['shopAddress'] ?? '').toString();
    _shopCityController.text = (data['shopCity'] ?? '').toString();
    _selectedCity = (data['shopCity'] ?? '').toString();
    _isVerified = data['isVerified'] == true;
    _verificationDocUrl = (data['verificationDocUrl'] ?? '').toString();
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _shopAddressController.dispose();
    _shopCityController.dispose();
    super.dispose();
  }

  Future<File?> _cropImage({
    required String sourcePath,
    required CropAspectRatioPreset aspectPreset,
    CropAspectRatio? fixedRatio,
    CropStyle cropStyle = CropStyle.rectangle,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          cropStyle: cropStyle,
          toolbarTitle: 'ပုံ Crop လုပ်ပါ',
          toolbarColor: const Color(0xFF1B5E20),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF4CAF50),
          initAspectRatio: aspectPreset,
          lockAspectRatio: fixedRatio != null,
          aspectRatioPresets: [aspectPreset],
        ),
        IOSUiSettings(
          cropStyle: cropStyle,
          title: 'ပုံ Crop လုပ်ပါ',
          aspectRatioLockEnabled: fixedRatio != null,
          resetAspectRatioEnabled: fixedRatio == null,
          aspectRatioPresets: [aspectPreset],
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  Future<void> _captureVerificationDoc() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return;
    
    // License docs usually 4:3 or similar
    final cropped = await _cropImage(
      sourcePath: picked.path,
      aspectPreset: CropAspectRatioPreset.ratio4x3,
    );
    if (cropped == null) return;
    setState(() => _verificationFile = cropped);
  }

  Future<void> _uploadVerificationDoc() async {
    if (_verificationFile == null) return;
    
    setState(() => _isUploadingDoc = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final url = await _uploadToStorage(
        file: _verificationFile!,
        path: 'verification_docs/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'verificationDocUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Send notification to ALL admins
      try {
        final adminsSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
            
        for (final adminDoc in adminsSnap.docs) {
          createNotification(
            userId: adminDoc.id,
            type: 'verify_request',
            title: 'Seller Verify တောင်းဆိုချက် အသစ် 🆕',
            body: '${_nameController.text} မှ ဆိုင်လိုင်စင် တင်ပြထားပါသည်။ စစ်ဆေးပေးပါ။',
            targetRole: 'admin',
            senderName: _nameController.text,
          ).catchError((e) => debugPrint('❌ Admin noti failed: $e'));
        }
      } catch (e) {
        debugPrint('❌ Failed to find admins for noti: $e');
      }

      if (mounted) {
        setState(() {
          _verificationDocUrl = url;
          _verificationFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("လိုင်စင်ပုံ တင်ပြပြီးပါပြီ။ Admin မှ စစ်ဆေးပေးပါမည်။")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingDoc = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    // Circle crop — 1:1 ratio
    final cropped = await _cropImage(
      sourcePath: picked.path,
      aspectPreset: CropAspectRatioPreset.square,
      fixedRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      cropStyle: CropStyle.circle,
    );
    if (cropped == null) return;
    setState(() => _profileFile = cropped);
  }

  Future<void> _pickCoverImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    // Cover — wide landscape crop (free ratio)
    final cropped = await _cropImage(
      sourcePath: picked.path,
      aspectPreset: CropAspectRatioPreset.ratio16x9,
    );
    if (cropped == null) return;
    setState(() => _coverFile = cropped);
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

      // ✅ Check if name is already taken by ANOTHER verified seller
      if (name != widget.currentName) {
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
      }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile ပြင်ဆင်ပြီးပါပြီ")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSetPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("စကားဝှက်အသစ် သတ်မှတ်ရန်"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Google ဖြင့် ဝင်ထားသောကြောင့် စကားဝှက်မရှိသေးပါ။ Password ဖြင့်ပါ ဝင်နိုင်ရန် စကားဝှက်အသစ် သတ်မှတ်ပါ။",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: "Password အသစ် (အနည်းဆုံး ၈ လုံး)",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("မလုပ်တော့ပါ"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final password = passwordController.text.trim();
                    if (password.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Password က အနည်းဆုံး ၈ လုံး ရှိရပါမည်")),
                      );
                      return;
                    }
                    if (!RegExp(r'(?=.*[A-Z])').hasMatch(password) || !RegExp(r'(?=.*\d)').hasMatch(password)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Password မှာ အကြီးစာလုံး (A-Z) နှင့် နံပါတ် (0-9) ပါရမည်")),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );

                    final nav = Navigator.of(context, rootNavigator: true);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null && user.email != null) {
                        AuthCredential credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: password,
                        );
                        await user.linkWithCredential(credential);
                        nav.pop(); // dismiss loading
                        messenger.showSnackBar(
                          const SnackBar(content: Text("စကားဝှက် အောင်မြင်စွာ သတ်မှတ်ပြီးပါပြီ။ နောက်တစ်ကြိမ်တွင် Password ဖြင့်ပါ ဝင်နိုင်ပါပြီ။")),
                        );
                        setState(() {}); // refresh UI
                      }
                    } catch (e) {
                      nav.pop(); // dismiss loading
                      messenger.showSnackBar(
                        SnackBar(content: Text("စကားဝှက် သတ်မှတ်ခြင်း မအောင်မြင်ပါ: $e")),
                      );
                    }
                  },
                  child: const Text("သတ်မှတ်မည်"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("စကားဝှက်ပြောင်းရန် Link ကို သင့် Email သို့ ပို့ပေးလိုက်ပါပြီ။")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    final passwordController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final isPasswordUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("အကောင့်ဖျက်ရန် သေချာပါသလား?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "အကောင့်ဖျက်လိုက်ပါက သင်တင်ထားသော စာရင်းများ၊ ကုန်ပစ္စည်းများနှင့် ကိုယ်ရေးအချက်အလက်များ အားလုံး အပြီးအပိုင် ပျက်သွားမည်ဖြစ်ပြီး ပြန်လည်ရယူ၍ မရတော့ပါ။",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (isPasswordUser) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "သင့်လက်ရှိ စကားဝှက် (Password) ထည့်ပါ",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (isGoogleUser) ...[
                const SizedBox(height: 12),
                Text(
                  isPasswordUser 
                      ? "(သို့) စကားဝှက်မရှိပါက ဆက်လက်နှိပ်၍ Google ဖြင့် အတည်ပြုနိုင်ပါသည်။"
                      : "Google အကောင့်ဖြင့် အတည်ပြုရန် ဆက်လက်လုပ်ဆောင်ပါမည်။",
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteUserAccount(passwordController.text.trim());
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUserAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    AppConfig.isDeletingAccount = true;

    final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');
    final isPasswordUser = user.providerData.any((p) => p.providerId == 'password');

    // Show loading dialog immediately so the user sees activity right away
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      bool reauthenticated = false;

      // 1. Try password first if user entered one and has password provider
      if (isPasswordUser && password.isNotEmpty) {
        try {
          AuthCredential credential = EmailAuthProvider.credential(
            email: user.email ?? '',
            password: password,
          );
          await user.reauthenticateWithCredential(credential);
          reauthenticated = true;
        } catch (e) {
          debugPrint("Password re-auth failed: $e");
          throw Exception("စကားဝှက် မှားယွင်းနေပါသည်။ ကျေးဇူးပြု၍ စကားဝှက် မှန်ကန်စွာ ထည့်ပါ။");
        }
      }

      // 2. If not yet reauthenticated and Google user, try Google sign-in
      if (!reauthenticated && isGoogleUser) {
        try {
          await GoogleSignIn.instance.initialize();
          final googleUser = await GoogleSignIn.instance.authenticate();
          final googleAuth = googleUser.authentication;
          if (googleAuth.idToken != null) {
            final credential = GoogleAuthProvider.credential(
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(credential);
            reauthenticated = true;
          } else {
            throw Exception("Google ID token is null");
          }
        } catch (e) {
          debugPrint("Google re-auth failed: $e");
          throw Exception("Google ဖြင့် အတည်ပြုခြင်း မအောင်မြင်ပါ: $e");
        }
      }

      if (!reauthenticated) {
        throw Exception("အကောင့်ဖျက်ရန် စကားဝှက် သို့မဟုတ် Google ဖြင့် အတည်ပြုရန် လိုအပ်ပါသည်။");
      }

      final uid = user.uid;

      // Delete user document from Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint("Failed to delete user doc: $e");
      }

      // Delete user products/listings
      try {
        final productsQuery = await FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: uid)
            .get();

        for (var doc in productsQuery.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint("Failed to delete user products: $e");
      }

      // Delete Firebase Auth user
      await user.delete();

      // ✅ Clear Google Sign-In session/cache
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint("Google Sign-In signOut failed: $e");
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      // Navigate to login / root
      context.go(AppRoutes.login);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully deleted")),
      );
    } catch (e) {
      AppConfig.isDeletingAccount = false;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("အကောင့်ဖျက်ခြင်း မအောင်မြင်ပါ: ${e.toString().replaceAll('Exception: ', '')}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandAppBar(title: "Profile ပြင်ဆင်ရန်"),
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
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _coverFile != null
                  ? Image.file(_coverFile!, fit: BoxFit.cover)
                  : (_coverUrl.isNotEmpty
                        ? AppNetworkImage(
                            _coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Center(child: Icon(Icons.broken_image_outlined)),
                          )
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
                  : (_profileUrl.isNotEmpty ? NetworkImage(_profileUrl) : null)
                        as ImageProvider?,
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

            // ✅ Searchable city picker — uses same Firestore city list as order form
            GestureDetector(
              onTap: () async {
                final picked = await CityPickerSheet.show(context);
                if (picked != null && mounted) {
                  setState(() => _selectedCity = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'မြို့',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(
                  (_selectedCity?.isNotEmpty == true)
                      ? _selectedCity!
                      : 'မြို့ရွေးပါ',
                  style: TextStyle(
                    color: (_selectedCity?.isNotEmpty == true)
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _shopAddressController,
              decoration: const InputDecoration(
                labelText: "လိပ်စာ ထည့်ပါ",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),

            // ── VERIFICATION SECTION ──────────────────────────────────
            _buildVerificationSection(scheme, textTheme),

            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          "ပြင်ဆင်မှုများ သိမ်းမည်",
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password action button based on provider
                      Builder(
                        builder: (context) {
                          final user = FirebaseAuth.instance.currentUser;
                          final isPasswordUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;
                          if (isPasswordUser) {
                            return Column(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _sendPasswordResetEmail,
                                  icon: const Icon(Icons.lock_reset),
                                  label: const Text("စကားဝှက်ပြောင်းရန် (Reset Password)"),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showSetPasswordDialog(context),
                                  icon: const Icon(Icons.password),
                                  label: const Text("စကားဝှက် သတ်မှတ်ရန် (Set Password)"),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }
                        },
                      ),

                      OutlinedButton.icon(
                        onPressed: () => _showDeleteAccountConfirmation(context),
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text(
                          "Delete Account Permanently",
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationSection(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              "Seller Verification (Bridge)",
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        if (_isVerified)
          // ── Case 1: Already Verified ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "အတည်ပြုပြီးသော ဆိုင် ✅\nသင့်ဆိုင်သည် အစစ်အမှန်ဖြစ်ကြောင်း အသိအမှတ်ပြုထားပြီးဖြစ်သည်။",
                    style: textTheme.bodySmall?.copyWith(color: Colors.green.shade900),
                  ),
                ),
              ],
            ),
          )
        else if (_verificationDocUrl.isNotEmpty)
          // ── Case 2: Document Uploaded, Pending Review ──
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.secondary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, color: scheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "အတည်ပြုရန် စောင့်ဆိုင်းနေပါသည် ⏳\nAdmin မှ သင့်လိုင်စင်အား စစ်ဆေးနေပါသည်။",
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(
                  _verificationDocUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          )
        else
          // ── Case 3: Need to upload ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Appပေါ်တွင် သင့်ဆိုင်နှင့် နာမည်တူ ထပ်မရှိစေရန် သင့်ဆိုင်နာမည်အား verify လုပ်ရန် ဆိုင်လိုင်စင်ပုံအား တင်ပြပေးပါ။",
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (_verificationFile == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _captureVerificationDoc,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text("လိုင်စင်ပုံ ရိုက်မည် (Live Photo)"),
                  ),
                )
              else
                Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_verificationFile!, height: 180, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => setState(() => _verificationFile = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isUploadingDoc ? null : _uploadVerificationDoc,
                        icon: _isUploadingDoc 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_isUploadingDoc ? "တင်နေသည်..." : "အတည်ပြု တင်မည်"),
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

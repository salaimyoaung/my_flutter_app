import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class ReportPage extends StatefulWidget {
  final String? chatId;        // optional — null if reported from wall/product
  final String otherUserId;
  final String otherUserName;  // display name for context

  const ReportPage({
    super.key,
    this.chatId,
    required this.otherUserId,
    this.otherUserName = '',
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? _reason;
  final _descController = TextEditingController();
  bool _loading = false;

  File? _imageFile;
  final _picker = ImagePicker();

  static const List<String> _reasons = [
    'Spam',
    'Scam',
    'Abusive Language',
    'Fake Product',
    'Other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref()
        .child('reports')
        .child(user.uid)
        .child('$ts.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_reason == null) {
      _snack('Please select reason');
      return;
    }

    setState(() => _loading = true);

    try {
      // ── Duplicate guard ───────────────────────────────────────
      final existing = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedBy', isEqualTo: user.uid)
          .where('reportedUserId', isEqualTo: widget.otherUserId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        _snack('ဒီ user ကို အရင်ကတည်းက report လုပ်ပြီးပြီ');
        return;
      }

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      await FirebaseFirestore.instance.collection('reports').add({
        if (widget.chatId != null) 'chatId': widget.chatId,
        'reportedBy': user.uid,
        'reportedUserId': widget.otherUserId,
        'reason': _reason,
        'description': _descController.text.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      _snack('Report submitted');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(title: 'Report User'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Reason Dropdown ───────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _reason,
              hint: const Text('Select reason'),
              items: _reasons
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v),
            ),

            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Screenshot upload ─────────────────────────────────
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _imageFile == null
                    ? 'Screenshot Upload လုပ်ပါ'
                    : 'Screenshot ပြောင်းမည်',
              ),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _imageFile!,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────────
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}

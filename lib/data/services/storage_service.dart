import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// ⚠️  pubspec.yaml မှာ packages ထည့်ရမည်—
///   flutter_image_compress: ^2.3.0
///   path_provider: ^2.1.0
///   uuid: ^4.5.3
class StorageService {
  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  // ── Upload constants ───────────────────────────────────────────────────────
  static const int _maxImageBytes = 10 * 1024 * 1024; // 10 MB pre-compress guard
  static const int _maxImageCount = 10;
  static const String _defaultExt = 'jpg';

  // ── Compression settings ───────────────────────────────────────────────────
  static const int _compressQuality = 80;
  static const int _compressMaxWidth = 1920;
  static const int _compressMaxHeight = 1920;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<List<String>> uploadProductImages({
    required String uid,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) throw Exception('No image selected');

    // ✅ Deduplicate by path
    final unique = <String, XFile>{};
    for (final x in files) {
      unique.putIfAbsent(x.path, () => x);
    }

    // ✅ Enforce max image count
    final toUpload = unique.values.take(_maxImageCount).toList();

    // Use Future.wait to upload concurrently, but with unique IDs
    final results = await Future.wait(
      toUpload.asMap().entries.map((entry) async {
        final x = entry.value;

        try {
          // ✅ Safe extension extraction
          final name = p.basename(x.name).toLowerCase();
          final hasDot = name.contains('.');
          final ext = hasDot ? name.split('.').last : _defaultExt;

          final contentType = switch (ext) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'jpg' || 'jpeg' => 'image/jpeg',
            _ => 'image/jpeg',
          };

          // ✅ Guaranteed unique filename using UUID
          final fileId = _uuid.v4();
          final ref = _storage
              .ref()
              .child('products')
              .child(uid)
              .child('$fileId.$ext');

          if (kIsWeb) {
            // ── Web path: XFile → bytes → putData ─────────────────────────
            final bytes = await x.readAsBytes();
            if (bytes.length > _maxImageBytes) return null;
            await ref.putData(bytes, SettableMetadata(contentType: contentType));
          } else {
            // ── Mobile/desktop path: compress → putFile ───────────────────
            final file = File(x.path);
            final originalSize = await file.length();
            if (originalSize > _maxImageBytes) return null;

            final compressible =
                ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp';
            
            // ✅ Pass UUID to compress for unique temp file path
            final fileToUpload = compressible
                ? (await _compress(file, ext: ext, uniqueId: fileId) ?? file)
                : file;

            await ref.putFile(
              fileToUpload,
              SettableMetadata(contentType: contentType),
            );
          }

          return await ref.getDownloadURL();
        } catch (e) {
          if (kDebugMode) debugPrint('Upload per-file error: $e');
          return null; // isolate per-file failure
        }
      }),
    );

    return results.whereType<String>().toList();
  }

  // ── Compression helper (mobile only) ─────────────────────────────────────
  static Future<File?> _compress(File file,
      {required String ext, String uniqueId = ''}) async {
    try {
      final dir = await getTemporaryDirectory();
      // ✅ Use UUID for the local temp path to prevent race condition collisions
      final id = uniqueId.isNotEmpty ? uniqueId : _uuid.v4();
      final targetPath = '${dir.path}/${id}_c.$ext';

      final format = switch (ext) {
        'png' => CompressFormat.png,
        'webp' => CompressFormat.webp,
        _ => CompressFormat.jpeg,
      };

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: _compressQuality,
        minWidth: _compressMaxWidth,
        minHeight: _compressMaxHeight,
        format: format,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      if (kDebugMode) debugPrint('Compression error: $e');
      return null; // compression failed — caller uploads original
    }
  }

  // ── Generic single-file upload (XFile, web+mobile safe) ──────────────────
  /// Uploads any XFile to a given Storage path and returns the download URL.
  /// Used for IMEI photos, profile images, etc.
  Future<String> uploadXFile({
    required XFile file,
    required String storagePath,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(storagePath);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
    } else {
      await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: contentType),
      );
    }

    return ref.getDownloadURL();
  }

  // ── Cleanup helper ────────────────────────────────────────────────────────
  Future<void> deleteFiles(List<String> urls) async {
    await Future.wait(
      urls.map((url) async {
        try {
          await _storage.refFromURL(url).delete();
        } catch (e) {
          if (kDebugMode) debugPrint('Delete file error: $url -> $e');
        }
      }),
    );
  }
}

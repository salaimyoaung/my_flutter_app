import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<List<String>> uploadProductImages({
    required String uid,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) {
      throw Exception("No image selected");
    }

    final unique = <String, XFile>{};
    for (final x in files) {
      unique.putIfAbsent(x.path, () => x);
    }

    final urls = <String>[];
    var index = 0;
    for (final x in unique.values) {
      final file = File(x.path);
      final name = (x.name).toLowerCase();
      final hasDot = name.contains('.');
      final ext = hasDot ? name.split('.').last : 'jpg';

      final ref = _storage
          .ref()
          .child('products')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}_$index.$ext');

      final lowerExt = ext.toLowerCase();
      final contentType = switch (lowerExt) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        _ => 'image/jpeg',
      };
      final meta = SettableMetadata(contentType: contentType);

      await ref.putFile(file, meta);
      final url = await ref.getDownloadURL();
      urls.add(url);
      index += 1;
    }

    return urls;
  }
}

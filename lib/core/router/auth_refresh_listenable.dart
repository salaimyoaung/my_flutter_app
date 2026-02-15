import 'dart:async';

import 'package:flutter/foundation.dart';

class AuthRefreshListenable extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  AuthRefreshListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'core/services/presence_service.dart';
import 'data/services/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/router/app_navigator_keys.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );
  } catch (e) {
    if (kDebugMode) debugPrint("Background App Check activation failed: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase init
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ Crashlytics
    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // ✅ AppCheck Fix: Emulator/Debug mode မှာ အလုပ်လုပ်အောင် Debug Provider ကို သုံးပါသည်
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("App Check activation failed: $e");
    }
  } catch (e, stack) {
    if (!kIsWeb && !kDebugMode) {
      FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }

  // 2–5) Mobile-only features
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationNavigation(message.data);
    });

    await Future.wait([
      NotificationService.init().catchError((e, stack) {
        if (!kDebugMode) FirebaseCrashlytics.instance.recordError(e, stack);
        return null;
      }),
      FirebaseMessaging.instance.getInitialMessage().then((initialMsg) {
        if (initialMsg != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationNavigation(initialMsg.data);
          });
        }
      }).catchError((e, stack) {
        if (!kDebugMode) FirebaseCrashlytics.instance.recordError(e, stack);
      }),
    ]);
  }

  runApp(const ProviderScope(child: MyMarketplaceApp()));
}

void _handleNotificationNavigation(Map<String, dynamic> data) {
  // ✅ Safety Check: Use a small delay if router is being initialized
  //    Or if this is called before the first build.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final router = appRouter;
    if (router == null) return;

    final type = data['type'];
    if (type == 'chat') {
      final chatId = data['chatId'];
      final otherUserId = (data['otherUserId'] ?? data['senderId'] ?? '').toString();
      if (chatId == null || chatId.toString().isEmpty) {
        router.push(AppRoutes.chats);
        return;
      }
      router.push(AppRoutes.chat, extra: {
        'chatId': chatId.toString(),
        'otherUserId': otherUserId,
      });
    } else if (type == 'order') {
      final orderId = data['orderId'];
      if (orderId == null || orderId.toString().isEmpty) {
        router.push(AppRoutes.notifications);
        return;
      }
      router.push(AppRoutes.orderDetail, extra: {
        'orderId': orderId.toString(),
      });
    } else {
      router.push(AppRoutes.notifications);
    }
  });
}

class MyMarketplaceApp extends ConsumerStatefulWidget {
  const MyMarketplaceApp({super.key});

  @override
  ConsumerState<MyMarketplaceApp> createState() => _MyMarketplaceAppState();
}

class _MyMarketplaceAppState extends ConsumerState<MyMarketplaceApp>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot?>? _userDocSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PresenceService.setOnline();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userDocSub?.cancel();
      if (user != null) {
        PresenceService.setOnline();
        if (!kIsWeb) {
          NotificationService.saveTokenToUser().catchError((e) {
            if (kDebugMode) debugPrint("saveTokenToUser on authState error: $e");
          });
        }
        bool docEverExisted = false;

        // ✅ Listen to user doc in Firestore to detect if account was deleted on another device
        _userDocSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((docSnap) async {
          if (docSnap.exists) {
            docEverExisted = true;
          } else {
            // Only trigger sign-out if the document existed previously in this session and user is not deleting their own account
            if (docEverExisted && !AppConfig.isDeletingAccount) {
              // Account was deleted on another device! Force sign out immediately.
              await FirebaseAuth.instance.signOut();
              rootMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('ဤအကောင့်မှာ အခြားစက်တွင် ဖျက်သိမ်းသွားပြီဖြစ်ပါသည်။')),
              );
            }
          }
        }, onError: (e) {
          if (kDebugMode) debugPrint("User doc watch error: $e");
        });
      } else {
        PresenceService.setOffline();
      }
    });

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.saveTokenToUser();
        } catch (e, stack) {
          FirebaseCrashlytics.instance.recordError(e, stack);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _userDocSub?.cancel();
    PresenceService.setOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PresenceService.setOnline();
    } else {
      PresenceService.setOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    setGlobalRouter(router);

    return MaterialApp.router(
      title: 'Sigma Moby',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}

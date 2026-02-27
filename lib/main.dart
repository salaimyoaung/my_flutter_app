// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'data/services/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/router/app_navigator_keys.dart';
import 'core/theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase init
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ App Check MUST be activated right after Firebase init
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug, // ✅ DEV
      appleProvider: AppleProvider.debug,
    );

    final app = Firebase.app();
    debugPrint("PROJECT_ID = ${app.options.projectId}");
    debugPrint("APP_ID = ${app.options.appId}");
    debugPrint("✅ AppCheck activated (DEBUG)");
  } catch (e) {
    debugPrint("Firebase/AppCheck init error: $e");
  }

  // 2) Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3) AdMob init (optional)
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("MobileAds init error: $e");
  }

  // 4) Notification init
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint("Notification init error: $e");
  }

  // 5) Notification tap handlers (background -> open)
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    appRouter.push(AppRoutes.notifications);
  });

  // 6) Terminated -> open
  try {
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.push(AppRoutes.notifications);
      });
    }
  } catch (e) {
    debugPrint("getInitialMessage error: $e");
  }

  runApp(const MyMarketplaceApp());
}

class MyMarketplaceApp extends StatefulWidget {
  const MyMarketplaceApp({super.key});

  @override
  State<MyMarketplaceApp> createState() => _MyMarketplaceAppState();
}

class _MyMarketplaceAppState extends State<MyMarketplaceApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.saveTokenToUser();
      } catch (e) {
        debugPrint("saveTokenToUser error: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: appRouter,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}

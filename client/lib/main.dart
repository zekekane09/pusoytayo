import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusoy_tayo/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional at boot. Until google-services / firebase_options are
  // fully wired (and a backend is reachable), initialization can fail — we must
  // not let that crash the app, so the UI still loads for local/demo use.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped (not configured yet): $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E21),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    const ProviderScope(
      child: PusoyTayoApp(),
    ),
  );
}

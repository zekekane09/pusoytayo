import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusoy_tayo/core/router/app_router.dart';
import 'package:pusoy_tayo/core/theme/app_theme.dart';

class PusoyTayoApp extends ConsumerWidget {
  const PusoyTayoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Pusoy Tayo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

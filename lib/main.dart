import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: FeiniuPlayerApp()));
}

class FeiniuPlayerApp extends ConsumerWidget {
  const FeiniuPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Feiniu Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: !auth.initialized
          ? const _SplashScreen()
          : auth.isLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

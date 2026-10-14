import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
import 'sync_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SyncController.instance.start();
  runApp(const RecipesBookApp());
  // Автопроверка обновлений — после первого кадра, чтобы не тормозить запуск.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkForUpdates();
  });
}

Future<void> _checkForUpdates() async {
  final info = await UpdateService.instance.checkForUpdate();
  if (info == null) return;
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  if (!ctx.mounted) return;
  showDialog(
    context: ctx,
    builder: (_) => UpdateDialog(info: info),
  );
}

/// Глобальный нотификатор режима темы.
final ValueNotifier<AppThemeMode> themeModeNotifier =
    ValueNotifier<AppThemeMode>(AppThemeMode.system);

/// Глобальный ключ навигатора — нужен для показа диалогов из `main`.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class RecipesBookApp extends StatelessWidget {
  const RecipesBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return ValueListenableBuilder<AppThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              title: 'Книга рецептов',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              themeMode: _toMaterialThemeMode(mode),
              theme: buildLightTheme(dynamicScheme: lightDynamic?.harmonized()),
              darkTheme: buildDarkTheme(
                dynamicScheme: darkDynamic?.harmonized(),
              ),
              locale: const Locale('ru', 'RU'),
              supportedLocales: const [Locale('ru', 'RU')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const _Bootstrap(),
            );
          },
        );
      },
    );
  }

  ThemeMode _toMaterialThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

/// Загружает сохранённый режим темы перед показом главного экрана.
/// Слушает состояние входа и решает, что показать: приложение или экран входа.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _themeReady = false;
  bool _skipAuth = false;
  bool _skipAuthLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = StorageService.instance;
    final raw = await s.loadThemeMode();
    final skip = await s.loadSkipAuth();
    themeModeNotifier.value = AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
    if (!mounted) return;
    setState(() {
      _themeReady = true;
      _skipAuth = skip;
      _skipAuthLoaded = true;
    });
  }

  Future<void> _skipAuthAndContinue() async {
    await StorageService.instance.saveSkipAuth(true);
    if (!mounted) return;
    setState(() => _skipAuth = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeReady || !_skipAuthLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ValueListenableBuilder<User?>(
      valueListenable: AuthService.instance.userNotifier,
      builder: (context, user, _) {
        if (user != null) return const HomeScreen();
        if (_skipAuth) return const HomeScreen();
        return AuthScreen(onSkip: _skipAuthAndContinue);
      },
    );
  }
}

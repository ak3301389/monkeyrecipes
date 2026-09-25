import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecipesBookApp());
}

/// Глобальный нотификатор режима темы.
final ValueNotifier<AppThemeMode> themeModeNotifier =
    ValueNotifier<AppThemeMode>(AppThemeMode.system);

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
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.instance.loadThemeMode();
    themeModeNotifier.value = AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const HomeScreen();
  }
}

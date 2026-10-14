import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Экран входа через Google.
class AuthScreen extends StatefulWidget {
  final VoidCallback? onSkip;

  const AuthScreen({super.key, this.onSkip});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  Future<void> _signIn() async {
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      // Ничего не делаем — userNotifier переключит экран.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('❌ Ошибка: $e')));
    }
  }

  String _localizeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Этот email уже привязан к другому способу входа';
      case 'invalid-credential':
        return 'Неверные данные для входа';
      case 'popup-blocked':
        return 'Браузер заблокировал всплывающее окно. Разрешите попапы для этого сайта.';
      case 'popup-closed-by-user':
        return 'Окно входа было закрыто';
      case 'unauthorized-domain':
        return 'Домен не авторизован в Firebase. Добавьте его в Authentication → Settings → Authorized domains.';
      default:
        return e.message ?? 'Ошибка авторизации: ${e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      size: 56,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Книга рецептов',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Войдите, чтобы ваши рецепты синхронизировались между устройствами',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _signIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Войти через Google'),
                    ),
                  ),
                  if (widget.onSkip != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: widget.onSkip,
                        child: const Text('Продолжить без входа'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

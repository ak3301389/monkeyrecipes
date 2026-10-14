import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'services/backup_service.dart';

/// Глобальный контроллер синхронизации.
/// Слушает вход/выход и автоматически подтягивает/заливает данные.
class SyncController {
  SyncController._();
  static final SyncController instance = SyncController._();

  StreamSubscription<User?>? _sub;
  bool _busy = false;

  /// Запускается один раз при старте приложения.
  void start() {
    _sub ??= AuthService.instance.authStateChanges().listen(_onAuthChanged);
    // И сразу проверяем текущее состояние (если уже вошёл).
    _onAuthChanged(AuthService.instance.currentUser);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) return;
    if (_busy) return;
    _busy = true;
    try {
      final hasCloud = await BackupService.instance.hasCloudData();
      if (hasCloud) {
        // Данные в облаке есть — загружаем их.
        await BackupService.instance.loadAll();
      } else {
        // Облако пустое — заливаем локальные данные.
        await BackupService.instance.saveAll();
      }
    } catch (_) {
      // Тихо игнорируем — не блокируем приложение.
    } finally {
      _busy = false;
    }
  }

  /// Вызывать вручную после любого изменения данных.
  Future<void> pushToCloud() async {
    if (AuthService.instance.currentUser == null) return;
    try {
      await BackupService.instance.saveAll();
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

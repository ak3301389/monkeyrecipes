import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Информация о доступном обновлении.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? releaseNotes;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
  });
}

/// Сервис проверки обновлений с GitHub Releases.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String owner = 'ak3301389';
  static const String repo = 'monkeyrecipes';

  final Dio _dio = Dio();

  /// Проверяет, есть ли новая версия.
  /// Возвращает null, если обновления нет, или мы не на Android.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = '${info.version}+${info.buildNumber}';

      final resp = await _dio.get(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      if (resp.statusCode != 200) return null;

      final data = resp.data as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      if (tag.isEmpty) return null;

      // Ищем APK в assets.
      final assets = (data['assets'] as List<dynamic>?) ?? [];
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null) return null;

      // Сравниваем версии.
      if (!_isNewer(tag, current)) return null;

      return UpdateInfo(
        version: tag,
        downloadUrl: apkUrl,
        releaseNotes: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Скачивает APK, возвращает путь к файлу.
  Future<String?> downloadApk(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = Directory.systemTemp;
      final path = '${dir.path}/update.apk';
      await _dio.download(
        info.downloadUrl,
        path,
        onReceiveProgress: onProgress,
        options: Options(
          followRedirects: true,
          headers: {'Accept': 'application/octet-stream'},
        ),
      );
      return path;
    } catch (_) {
      return null;
    }
  }

  /// true, если tag (`v1.6.0.11`) новее, чем current (`1.5.0+9`).
  bool _isNewer(String tag, String current) {
    final t = tag.replaceAll(RegExp(r'^v'), '').replaceAll('+', '.');
    final c = current.replaceAll('+', '.');

    final tParts = t.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts = c.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final len = tParts.length > cParts.length ? tParts.length : cParts.length;
    for (var i = 0; i < len; i++) {
      final a = i < tParts.length ? tParts[i] : 0;
      final b = i < cParts.length ? cParts[i] : 0;
      if (a > b) return true;
      if (a < b) return false;
    }
    return false;
  }
}

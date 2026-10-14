import 'dart:io';

import 'package:github_release_apk_updater/github_release_apk_updater.dart';
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

  final _updater = GithubReleaseApkUpdater();
  final _api = GithubApiService();
  final _downloader = ApkDownloaderService();
  final _comparator = VersionComparator();

  /// Проверяет, есть ли новая версия.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = '${info.version}+${info.buildNumber}';

      final supportedAbis = await _updater.getSupportedAbis();

      final release = await _api.getLatestGithubAPKRelease(
        ownerGithub: owner,
        repositoryGithub: repo,
        apkKeyName: '',
        supportedAbis: supportedAbis,
      );
      if (release == null) return null;

      final isNewer = _comparator.isNewerVersion(release.version, current);
      if (!isNewer) return null;

      return UpdateInfo(version: release.version, downloadUrl: release.apkUrl);
    } catch (_) {
      return null;
    }
  }

  /// Скачивает APK и запускает установщик.
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final filePath = await _downloader.downloadAPK(
      info.downloadUrl,
      null,
      onProgress,
    );
    if (filePath != null) {
      await _updater.installApk(filePath);
    }
  }
}

/// Конфигурация приложения.
/// Firebase Web-конфиг (публичные данные, apiKey не секрет).
class AppConfig {
  AppConfig._();

  static const String firebaseApiKey =
      'AIzaSyD9j0xpHImvzFm-l9GAaw2xXy7NQUt0Ovk';
  static const String firebaseAuthDomain =
      'monkeyrecipes-b6770.firebaseapp.com';
  static const String firebaseProjectId = 'monkeyrecipes-b6770';
  static const String firebaseStorageBucket =
      'monkeyrecipes-b6770.firebasestorage.app';
  static const String firebaseMessagingSenderId = '868705464245';
  static const String firebaseAppId =
      '1:868705464245:web:521efffbb9cdfcc0d533fc';

  /// GitHub-репозиторий для автообновления.
  static const String githubOwner = 'ak3301389';
  static const String githubRepo = 'monkeyrecipes';
}

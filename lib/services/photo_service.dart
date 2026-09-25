import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;

/// Сжатие и подготовка фото рецепта.
///
/// На Web сохраняется как data-URL (base64) — кладётся в поле photoUrl.
/// На Android пока сохраняется так же (data-URL) — позже можно перейти
/// на файловую систему через path_provider.
class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  /// Максимальная сторона изображения после сжатия.
  static const int maxSide = 1024;

  /// JPEG-качество (0..100).
  static const int quality = 80;

  /// Принимает исходные байты, возвращает сжатые байты в JPEG.
  Future<Uint8List> compress(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    int w = decoded.width;
    int h = decoded.height;
    final longest = w > h ? w : h;
    if (longest > maxSide) {
      final scale = maxSide / longest;
      w = (w * scale).round();
      h = (h * scale).round();
    }

    final resized = img.copyResize(
      decoded,
      width: w,
      height: h,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// Преобразует сжатые байты в data-URL для хранения.
  String bytesToDataUrl(Uint8List bytes) {
    final b64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$b64';
  }

  /// Извлекает байты из data-URL. Возвращает null, если строка не data-URL.
  Uint8List? dataUrlToBytes(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image/')) return null;
    final idx = dataUrl.indexOf(',');
    if (idx < 0) return null;
    try {
      return base64Decode(dataUrl.substring(idx + 1));
    } catch (_) {
      return null;
    }
  }

  /// true, если строка похожа на data-URL изображения.
  bool isDataUrl(String? value) =>
      value != null && value.startsWith('data:image/');

  /// true, если это локальный файл (путь начинается с / или file:).
  bool isLocalFile(String? value) {
    if (value == null || value.isEmpty) return false;
    if (kIsWeb) return false;
    return value.startsWith('/') || value.startsWith('file:');
  }
}

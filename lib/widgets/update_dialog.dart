import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// Диалог «Доступно обновление».
/// Возвращает true, если пользователь согласился скачать и установить.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double? _progress;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = null;
    });
    try {
      await UpdateService.instance.downloadAndInstall(
        widget.info,
        onProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Не удалось скачать: $e')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Доступно обновление'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Новая версия: ${widget.info.version}',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Установить сейчас?', style: text.bodyMedium),
          if (_downloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _progress == null
                  ? 'Подготовка…'
                  : 'Загрузка: ${(_progress! * 100).toStringAsFixed(0)} %',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: _downloading ? null : _download,
          child: Text(_downloading ? 'Загрузка…' : 'Скачать'),
        ),
      ],
    );
  }
}

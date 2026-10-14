import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/update_service.dart';

/// Диалог «Доступно обновление».
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final path = await UpdateService.instance.downloadApk(
      widget.info,
      onProgress: (received, total) {
        if (!mounted) return;
        if (total > 0) {
          setState(() => _progress = received / total);
        }
      },
    );

    if (!mounted) return;

    if (path == null) {
      setState(() {
        _downloading = false;
        _error = 'Не удалось скачать APK';
      });
      return;
    }

    setState(() {
      _downloading = false;
      _progress = 1;
    });

    await OpenFilex.open(path);
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
                  : 'Загрузка: ${((_progress ?? 0) * 100).toStringAsFixed(0)} %',
              style: text.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: text.bodySmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
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

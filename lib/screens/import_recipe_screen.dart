import 'package:flutter/material.dart';

import '../models.dart';
import '../services/recipe_import_service.dart';
import 'recipe_edit_screen.dart';

/// Экран импорта рецепта по ссылке.
class ImportRecipeScreen extends StatefulWidget {
  const ImportRecipeScreen({super.key});

  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends State<ImportRecipeScreen> {
  final _urlCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Вставьте ссылку на рецепт');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final recipe = await RecipeImportService.instance.importFromUrl(url);
      if (!mounted) return;

      // Открываем редактор с уже заполненным рецептом.
      final result = await Navigator.of(context).push<Recipe>(
        MaterialPageRoute(builder: (_) => RecipeEditScreen(initial: recipe)),
      );

      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось импортировать: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Импорт по ссылке')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вставьте ссылку на рецепт',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Работает с сайтами, у которых есть разметка рецепта (iamcook.ru).',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://www.iamcook.ru/showrecipe/...',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_busy ? 'Загрузка…' : 'Загрузить рецепт'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

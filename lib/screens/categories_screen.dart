import 'package:flutter/material.dart';

import '../icon_map.dart';
import '../models.dart';
import '../services/storage_service.dart';

/// Экран управления категориями.
/// Возвращает через Navigator.pop актуальный список категорий.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  bool _loading = true;

  /// Доступные иконки для категорий.
  static const List<String> _availableIcons = [
    'restaurant',
    'soup_kitchen',
    'eco',
    'dinner_dining',
    'cake',
    'local_cafe',
    'bakery_dining',
    'rice_bowl',
    'lunch_dining',
    'breakfast_dining',
    'icecream',
    'local_pizza',
    'fastfood',
    'ramen_dining',
    'set_meal',
    'egg',
    'liquor',
    'local_bar',
    'coffee',
    'emoji_food_beverage',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await StorageService.instance.loadCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await StorageService.instance.saveCategories(_categories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
            ? const Center(child: Text('Категорий пока нет'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  return ListTile(
                    leading: CircleAvatar(child: Icon(categoryIcon(c.icon))),
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Изменить',
                          onPressed: () => _editCategory(i),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Удалить',
                          onPressed: () => _deleteCategory(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    onTap: () => _editCategory(i),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Категория'),
      ),
    );
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Category>(
      context: context,
      builder: (_) => _CategoryDialog(icons: _availableIcons),
    );
    if (result == null || !mounted) return;
    setState(() => _categories.add(result));
    await _persist();
  }

  Future<void> _editCategory(int index) async {
    final result = await showDialog<Category>(
      context: context,
      builder: (_) =>
          _CategoryDialog(icons: _availableIcons, initial: _categories[index]),
    );
    if (result == null || !mounted) return;
    setState(() => _categories[index] = result);
    await _persist();
  }

  Future<void> _deleteCategory(int index) async {
    final c = _categories[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          '«${c.name}» будет удалена. Рецепты останутся, но потеряют категорию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _categories.removeAt(index));
    await _persist();
  }
}

/// Диалог создания/редактирования категории.
class _CategoryDialog extends StatefulWidget {
  final List<String> icons;
  final Category? initial;

  const _CategoryDialog({required this.icons, this.initial});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameCtrl;
  late String _icon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _icon = widget.initial?.icon ?? widget.icons.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Новая категория' : 'Категория'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Например: Супы',
              ),
            ),
            const SizedBox(height: 16),
            Text('Иконка', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.icons.map((name) {
                final selected = name == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = name),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Icon(categoryIcon(name), size: 22),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final id =
                widget.initial?.id ??
                'cat_${DateTime.now().millisecondsSinceEpoch}';
            Navigator.of(context)
                .pop(Category(id: id, name: name, icon: _icon));
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

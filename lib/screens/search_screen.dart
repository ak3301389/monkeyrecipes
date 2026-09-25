import 'package:flutter/material.dart';

import '../models.dart';

/// Экран поиска по рецептам.
/// Ищет по названию рецепта и по названиям ингредиентов.
/// Возвращает через Navigator.pop выбранный Recipe или null.
class SearchScreen extends StatefulWidget {
  final List<Recipe> recipes;
  final List<Category> categories;

  const SearchScreen({
    super.key,
    required this.recipes,
    required this.categories,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  String _query = '';
  String? _categoryId; // null = все категории

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _queryCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Название или ингредиент',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _queryCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            if (widget.categories.isNotEmpty)
              _CategoryChips(
                categories: widget.categories,
                selectedId: _categoryId,
                onSelected: (id) => setState(() => _categoryId = id),
              ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final results = _search();
    if (_query.trim().isEmpty && _categoryId == null) {
      return const _EmptyState(
        icon: Icons.search,
        title: 'Начните вводить запрос',
        subtitle: 'Можно искать по названию рецепта или по ингредиентам',
      );
    }
    if (results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте изменить запрос или выбрать другую категорию',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = results[i];
        return _ResultTile(
          recipe: r,
          categoryName: _categoryName(r.categoryId),
          onTap: () => Navigator.of(context).pop(r),
        );
      },
    );
  }

  List<Recipe> _search() {
    final q = _query.trim().toLowerCase();
    return widget.recipes.where((r) {
      if (_categoryId != null && r.categoryId != _categoryId) return false;
      if (q.isEmpty) return true;
      if (r.title.toLowerCase().contains(q)) return true;
      for (final ing in r.ingredients) {
        if (ing.name.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  String _categoryName(String id) {
    if (id.isEmpty) return '';
    return widget.categories
        .firstWhere(
          (c) => c.id == id,
          orElse: () => Category(id: '', name: ''),
        )
        .name;
  }
}

class _CategoryChips extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return FilterChip(
              label: const Text('Все'),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
            );
          }
          final c = categories[i - 1];
          return FilterChip(
            label: Text(c.name),
            selected: selectedId == c.id,
            onSelected: (_) => onSelected(c.id),
          );
        },
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Recipe recipe;
  final String categoryName;
  final VoidCallback onTap;

  const _ResultTile({
    required this.recipe,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(Icons.restaurant, color: scheme.onSecondaryContainer),
        ),
        title: Text(
          recipe.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            if (categoryName.isNotEmpty) ...[
              Text(categoryName),
              const SizedBox(width: 8),
            ],
            if (recipe.cookingMinutes > 0) ...[
              Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${recipe.cookingMinutes} мин'),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

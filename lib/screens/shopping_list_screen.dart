import 'package:flutter/material.dart';

import '../models.dart';
import '../services/storage_service.dart';

/// Экран списка покупок.
/// Возвращает через Navigator.pop актуальный список.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<ShoppingItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await StorageService.instance.loadShoppingItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await StorageService.instance.saveShoppingItems(_items);
  }

  @override
  Widget build(BuildContext context) {
    final notDone = _items.where((e) => !e.done).toList();
    final done = _items.where((e) => e.done).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупки'),
        actions: [
          if (_items.any((e) => e.done))
            IconButton(
              tooltip: 'Снять все галочки',
              icon: const Icon(Icons.refresh),
              onPressed: _resetDone,
            ),
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Очистить список',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClearAll,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? const _EmptyShopping()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (notDone.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Купить (${notDone.length})'),
                    ...notDone.map(
                      (e) => _ShoppingTile(
                        item: e,
                        onToggle: () => _toggle(e),
                        onDelete: () => _delete(e),
                      ),
                    ),
                  ],
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionHeader(context, 'Куплено (${done.length})'),
                    ...done.map(
                      (e) => _ShoppingTile(
                        item: e,
                        onToggle: () => _toggle(e),
                        onDelete: () => _delete(e),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _toggle(ShoppingItem item) async {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;
    setState(() => _items[idx].done = !_items[idx].done);
    await _persist();
  }

  Future<void> _delete(ShoppingItem item) async {
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _persist();
  }

  Future<void> _resetDone() async {
    setState(() {
      for (final it in _items) {
        it.done = false;
      }
    });
    await _persist();
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить список?'),
        content: const Text('Все покупки будут удалены из списка.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _items.clear());
    await _persist();
  }
}

// ───────── Пустое состояние ─────────
class _EmptyShopping extends StatelessWidget {
  const _EmptyShopping();

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
            Icon(Icons.shopping_cart_outlined, size: 72, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'Список покупок пуст',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Откройте рецепт и нажмите «В список покупок», чтобы добавить ингредиенты',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── Строка покупки ─────────
class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ShoppingTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final amount = item.amount > 0
        ? (item.amount == item.amount.roundToDouble()
              ? item.amount.toInt().toString()
              : item.amount.toString())
        : '';
    final qty = [amount, item.unit].where((e) => e.isNotEmpty).join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: item.done
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Checkbox(value: item.done, onChanged: (_) => onToggle()),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: text.bodyLarge?.copyWith(
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.recipeTitle.isNotEmpty)
                        Text(
                          item.recipeTitle,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (qty.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      qty,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        decoration: item.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

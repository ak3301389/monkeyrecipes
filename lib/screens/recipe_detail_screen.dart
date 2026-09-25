import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/photo_service.dart';
import 'photo_view_screen.dart';
import 'recipe_edit_screen.dart';

/// Экран просмотра рецепта.
/// Возвращает через Navigator.pop:
///   - Recipe — обновлённый рецепт (после редактирования или смены избранного);
///   - 'delete' — если пользователь удалил рецепт;
///   - null — если ничего не менялось.
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final String categoryName;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.categoryName = '',
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _recipe;

  late final List<Uint8List> _photoBytesList;
  final _photoPageCtrl = PageController();
  int _photoPage = 0;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _photoBytesList = _recipe.photos
        .map(_decodePhoto)
        .whereType<Uint8List>()
        .toList();
  }

  static Uint8List? _decodePhoto(String url) {
    if (url.isEmpty) return null;
    if (PhotoService.instance.isDataUrl(url)) {
      return PhotoService.instance.dataUrlToBytes(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe.title),
        actions: [
          IconButton(
            tooltip: _recipe.favorite ? 'Убрать из избранного' : 'В избранное',
            onPressed: _toggleFavorite,
            icon: Icon(_recipe.favorite ? Icons.star : Icons.star_border),
          ),
          IconButton(
            tooltip: 'Редактировать',
            onPressed: _openEditor,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_photoBytesList.isNotEmpty) ...[
              _buildPhotoCarousel(),
              const SizedBox(height: 16),
            ],
            _buildMeta(scheme, text),
            const SizedBox(height: 20),
            if (_recipe.ingredients.isNotEmpty) ...[
              _buildSectionTitle('Ингредиенты', text, scheme),
              const SizedBox(height: 8),
              ..._recipe.ingredients.map(
                (ing) => _IngredientRow(ingredient: ing),
              ),
              const SizedBox(height: 20),
            ],
            if (_recipe.steps.isNotEmpty) ...[
              _buildSectionTitle('Приготовление', text, scheme),
              const SizedBox(height: 8),
              ...List.generate(
                _recipe.steps.length,
                (i) => _StepRow(
                  index: i + 1,
                  step: _recipe.steps[i],
                  onPhotoTap: () => _openStepPhoto(_recipe.steps[i]),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_recipe.notes.trim().isNotEmpty) ...[
              _buildSectionTitle('Заметки', text, scheme),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_recipe.notes, style: text.bodyMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(ColorScheme scheme, TextTheme text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.categoryName.isNotEmpty)
          _MetaPill(icon: Icons.category_outlined, label: widget.categoryName),
        if (_recipe.cookingMinutes > 0)
          _MetaPill(
            icon: Icons.schedule,
            label: _formatMinutes(_recipe.cookingMinutes),
          ),
        _MetaPill(
          icon: Icons.list_alt,
          label: '${_recipe.ingredients.length} ингр.',
        ),
        _MetaPill(
          icon: Icons.format_list_numbered,
          label: '${_recipe.steps.length} шаг(ов)',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, TextTheme text, ColorScheme scheme) {
    return Text(
      title,
      style: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );
  }

  @override
  void dispose() {
    _photoPageCtrl.dispose();
    super.dispose();
  }

  Widget _buildPhotoCarousel() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final dy = event.scrollDelta.dy;
                  if (dy > 0) {
                    _photoPageCtrl.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  } else if (dy < 0) {
                    _photoPageCtrl.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                }
              },
              child: PageView.builder(
                controller: _photoPageCtrl,
                itemCount: _photoBytesList.length,
                onPageChanged: (i) => setState(() => _photoPage = i),
                itemBuilder: (context, i) {
                  return InkWell(
                    onTap: () => _openPhotoFullscreen(i),
                    borderRadius: BorderRadius.circular(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _photoBytesList[i],
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_photoBytesList.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_photoBytesList.length, (i) {
              final active = i == _photoPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  void _openStepPhoto(RecipeStep step) {
    if (step.photoUrl == null) return;
    final bytes = PhotoService.instance.dataUrlToBytes(step.photoUrl);
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewScreen(photos: [bytes], initialIndex: 0),
      ),
    );
  }

  void _openPhotoFullscreen(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewScreen(
          photos: _photoBytesList,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _recipe.favorite = !_recipe.favorite);
    if (!mounted) return;
    Navigator.of(context).pop(_recipe);
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(builder: (_) => RecipeEditScreen(initial: _recipe)),
    );
    if (result == null || !mounted) return;
    setState(() => _recipe = result);
    if (!mounted) return;
    Navigator.of(context).pop(_recipe);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: Text(
          '«${_recipe.title}» будет удалён без возможности восстановления.',
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
    Navigator.of(context).pop('delete');
  }

  static String _formatMinutes(int m) {
    if (m < 60) return '$m мин';
    final h = m ~/ 60;
    final rest = m % 60;
    if (rest == 0) return '$h ч';
    return '$h ч $rest мин';
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: text.labelLarge),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final Ingredient ingredient;
  const _IngredientRow({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amount = ingredient.amount > 0
        ? (ingredient.amount == ingredient.amount.roundToDouble()
              ? ingredient.amount.toInt().toString()
              : ingredient.amount.toString())
        : '';
    final qty = [amount, ingredient.unit].where((e) => e.isNotEmpty).join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(ingredient.name, style: text.bodyLarge)),
          if (qty.isNotEmpty)
            Text(
              qty,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final RecipeStep step;
  final VoidCallback? onPhotoTap;

  const _StepRow({required this.index, required this.step, this.onPhotoTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bytes =
        step.photoUrl != null && PhotoService.instance.isDataUrl(step.photoUrl)
        ? PhotoService.instance.dataUrlToBytes(step.photoUrl)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.secondaryContainer,
                child: Text(
                  '$index',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Шаг $index',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (bytes != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: InkWell(
                onTap: onPhotoTap,
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 280,
                      maxHeight: 280,
                    ),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(step.text, style: text.bodyLarge),
        ],
      ),
    );
  }
}

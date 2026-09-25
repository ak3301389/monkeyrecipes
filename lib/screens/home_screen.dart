import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../icon_map.dart';
import '../services/photo_service.dart';
import '../models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'categories_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';
import 'search_screen.dart';

/// Главный экран приложения с нижней навигацией.
/// На широких экранах (Web, планшет) навигация переезжает в NavigationRail слева.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  List<Recipe> _recipes = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _filterCategoryId; // null = все

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = StorageService.instance;
    final recipes = await storage.loadRecipes();
    final categories = await storage.loadCategories();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await StorageService.instance.saveRecipes(_recipes);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        return isWide ? _buildWide() : _buildNarrow();
      },
    );
  }

  // ───────── Узкий экран: NavigationBar снизу ─────────
  Widget _buildNarrow() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(
            overscroll: false,
            scrollbars: false,
          ),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Рецепты',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Избранное',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }

  // ───────── Широкий экран: NavigationRail слева ─────────
  Widget _buildWide() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(
            overscroll: false,
            scrollbars: false,
          ),
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) => setState(() => _tabIndex = i),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: Text('Рецепты'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.star_border),
                    selectedIcon: Icon(Icons.star),
                    label: Text('Избранное'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Настройки'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  AppBar _buildAppBar() {
    const titles = ['Рецепты', 'Избранное', 'Настройки'];
    return AppBar(
      title: Text(titles[_tabIndex]),
      actions: [
        if (_tabIndex == 0)
          IconButton(
            tooltip: 'Категории',
            icon: const Icon(Icons.category_outlined),
            onPressed: _openCategories,
          ),
        IconButton(
          tooltip: 'Поиск',
          icon: const Icon(Icons.search),
          onPressed: _openSearch,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  List<Recipe> _filteredRecipes() {
    if (_filterCategoryId == null) return _recipes;
    return _recipes.where((r) => r.categoryId == _filterCategoryId).toList();
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) =>
            SearchScreen(recipes: _recipes, categories: _categories),
      ),
    );
    if (result == null || !mounted) return;
    await _openRecipe(result);
  }

  Future<void> _openCategories() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
    if (!mounted) return;
    // Обновляем список категорий, если что-то изменилось.
    final cats = await StorageService.instance.loadCategories();
    if (!mounted) return;
    setState(() => _categories = cats);
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _createRecipe,
      icon: const Icon(Icons.add),
      label: const Text('Рецепт'),
    );
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final idx = _recipes.indexWhere((r) => r.id == recipe.id);
    if (idx < 0) return;
    final updated = Recipe(
      id: recipe.id,
      title: recipe.title,
      categoryId: recipe.categoryId,
      cookingMinutes: recipe.cookingMinutes,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      favorite: !recipe.favorite,
      photos: recipe.photos,
      notes: recipe.notes,
    );
    setState(() => _recipes[idx] = updated);
    await _persist();
  }

  Future<void> _openRecipe(Recipe recipe) async {
    final categoryName = _categories
        .firstWhere(
          (c) => c.id == recipe.categoryId,
          orElse: () => Category(id: '', name: ''),
        )
        .name;

    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) =>
            RecipeDetailScreen(recipe: recipe, categoryName: categoryName),
      ),
    );
    if (result == null || !mounted) return;

    if (result == 'delete') {
      setState(() => _recipes.removeWhere((r) => r.id == recipe.id));
      await _persist();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Рецепт «${recipe.title}» удалён')),
        );
      return;
    }

    if (result is Recipe) {
      final idx = _recipes.indexWhere((r) => r.id == result.id);
      if (idx < 0) return;
      setState(() => _recipes[idx] = result);
      await _persist();
    }
  }

  Future<void> _confirmDeleteRecipe(Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: Text(
          '«${recipe.title}» будет удалён без возможности восстановления.',
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
    setState(() => _recipes.removeWhere((r) => r.id == recipe.id));
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Рецепт «${recipe.title}» удалён')),
      );
  }

  Future<void> _createRecipe() async {
    final result = await Navigator.of(
      context,
    ).push<Recipe>(MaterialPageRoute(builder: (_) => const RecipeEditScreen()));
    if (result == null || !mounted) return;
    setState(() => _recipes.insert(0, result));
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Рецепт «${result.title}» добавлен')),
      );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_tabIndex) {
      case 0:
        return Column(
          children: [
            _CategoryFilterBar(
              categories: _categories,
              selectedId: _filterCategoryId,
              onSelected: (id) => setState(() => _filterCategoryId = id),
            ),
            Expanded(
              child: _RecipesTab(
                recipes: _filteredRecipes(),
                categories: _categories,
                onOpen: _openRecipe,
                onFavorite: _toggleFavorite,
                onDelete: _confirmDeleteRecipe,
              ),
            ),
          ],
        );
      case 1:
        return const _FavoritesTab();
      case 2:
        return ValueListenableBuilder<AppThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) => _SettingsTab(
            themeMode: mode,
            onThemeModeChanged: (m) => themeModeNotifier.value = m,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ───────── Вкладка «Рецепты» ─────────
class _RecipesTab extends StatelessWidget {
  final List<Recipe> recipes;
  final List<Category> categories;
  final void Function(Recipe recipe) onOpen;
  final void Function(Recipe recipe) onFavorite;
  final void Function(Recipe recipe) onDelete;
  const _RecipesTab({
    required this.recipes,
    required this.categories,
    required this.onOpen,
    required this.onFavorite,
    required this.onDelete,
  });

  String _iconFor(String categoryId) {
    if (categoryId.isEmpty) return 'restaurant';
    for (final c in categories) {
      if (c.id == categoryId) return c.icon;
    }
    return 'restaurant';
  }

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const _EmptyState(
        icon: Icons.restaurant_menu,
        title: 'Пока нет рецептов',
        subtitle: 'Добавьте первый рецепт кнопкой ниже',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: recipes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _SwipeableRecipeCard(
        key: ValueKey(recipes[i].id),
        recipe: recipes[i],
        categoryIconName: _iconFor(recipes[i].categoryId),
        onTap: () => onOpen(recipes[i]),
        onFavorite: () => onFavorite(recipes[i]),
        onDelete: () => onDelete(recipes[i]),
      ),
    );
  }
}

// ───────── Вкладка «Избранное» ─────────
class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.star_border,
      title: 'Избранное пока пусто',
      subtitle: 'Отмечайте рецепты звёздочкой, чтобы они появились здесь',
    );
  }
}

// ───────── Вкладка «Настройки» ─────────
class _SettingsTab extends StatelessWidget {
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  const _SettingsTab({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
          'Оформление',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.system,
              label: Text('Системная'),
              icon: Icon(Icons.brightness_auto),
            ),
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.light,
              label: Text('Светлая'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.dark,
              label: Text('Тёмная'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (set) async {
            final mode = set.first;
            await StorageService.instance.saveThemeMode(mode.name);
            onThemeModeChanged(mode);
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Данные',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: scheme.surfaceContainerLow,
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('Экспорт в JSON'),
          subtitle: const Text('Появится в следующем шаге'),
          onTap: () => _showComingSoon(context, 'Экспорт'),
        ),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: scheme.surfaceContainerLow,
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Импорт из JSON'),
          subtitle: const Text('Появится в следующем шаге'),
          onTap: () => _showComingSoon(context, 'Импорт'),
        ),
        const SizedBox(height: 24),
        Text(
          'Синхронизация',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: scheme.surfaceContainerLow,
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Firebase'),
          subtitle: const Text('Появится позже'),
          onTap: () => _showComingSoon(context, 'Firebase'),
        ),
        const SizedBox(height: 24),
        Text(
          'Обновления',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: scheme.surfaceContainerLow,
          leading: const Icon(Icons.system_update_alt),
          title: const Text('Проверить обновления'),
          subtitle: const Text('Появится позже'),
          onTap: () => _showComingSoon(context, 'Обновления'),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature — в разработке')));
  }
}

// ───────── Пустое состояние ─────────
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

// ───────── Карточка рецепта ─────────
class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final String categoryIconName;
  final VoidCallback onTap;
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    this.categoryIconName = 'restaurant',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  categoryIcon(categoryIconName),
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (recipe.favorite)
                          Icon(Icons.star, size: 20, color: scheme.primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.schedule,
                          label: '${recipe.cookingMinutes} мин',
                        ),
                        const SizedBox(width: 12),
                        _MetaChip(
                          icon: Icons.list_alt,
                          label: '${recipe.ingredients.length} ингр.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_photoBytes(recipe.photos) != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _photoBytes(recipe.photos)!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Uint8List? _photoBytes(List<String> urls) {
    if (urls.isEmpty) return null;
    final url = urls.first;
    if (url.isEmpty) return null;
    if (PhotoService.instance.isDataUrl(url)) {
      return PhotoService.instance.dataUrlToBytes(url);
    }
    return null;
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SwipeableRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final String categoryIconName;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _SwipeableRecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onFavorite,
    required this.onDelete,
    this.categoryIconName = 'restaurant',
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _RecipeCard(
        recipe: recipe,
        onTap: onTap,
        categoryIconName: categoryIconName,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss_${recipe.id}'),
      background: _swipeBg(
        context,
        alignment: Alignment.centerLeft,
        color: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
        icon: recipe.favorite ? Icons.star_border : Icons.star,
      ),
      secondaryBackground: _swipeBg(
        context,
        alignment: Alignment.centerRight,
        color: scheme.errorContainer,
        fg: scheme.onErrorContainer,
        icon: Icons.delete_outline,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onFavorite();
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          onDelete();
          return false;
        }
        return false;
      },
      child: _RecipeCard(
        recipe: recipe,
        onTap: onTap,
        categoryIconName: categoryIconName,
      ),
    );
  }

  Widget _swipeBg(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required Color fg,
    required IconData icon,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: fg, size: 28),
    );
  }
}

class _CategoryFilterBar extends StatefulWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _CategoryFilterBar({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<_CategoryFilterBar> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print('[FilterBar] build called, categories=${widget.categories.length}');
    if (widget.categories.isEmpty) return const SizedBox.shrink();

    final chipSide = BorderSide.none;
    final chipLabelStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
    final chips = <Widget>[
      FilterChip(
        label: Text('Все', style: chipLabelStyle),
        selected: widget.selectedId == null,
        onSelected: (_) => widget.onSelected(null),
        showCheckmark: false,
        side: chipSide,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      ...widget.categories.map(
        (c) => FilterChip(
          label: Text(c.name, style: chipLabelStyle),
          selected: widget.selectedId == c.id,
          onSelected: (_) => widget.onSelected(c.id),
          showCheckmark: false,
          side: chipSide,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ];

    final row = ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(
        overscroll: false,
        scrollbars: false,
        physics: const ClampingScrollPhysics(),
      ),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );

    return SizedBox(
      height: 56,
      child: kIsWeb
          ? Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final delta = event.scrollDelta.dy != 0
                      ? event.scrollDelta.dy
                      : event.scrollDelta.dx;
                  final max = _scrollCtrl.position.maxScrollExtent;
                  final next = (_scrollCtrl.offset + delta).clamp(0.0, max);
                  _scrollCtrl.jumpTo(next);
                }
              },
              child: row,
            )
          : row,
    );
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Локальное хранилище на SharedPreferences.
/// Синглтон: доступ через StorageService.instance.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _kRecipes = 'recipes';
  static const _kCategories = 'categories';
  static const _kThemeMode = 'theme_mode';
  static const _kIngredientNames = 'ingredient_names';
  static const _kIngredientUnits = 'ingredient_units';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ───────── Рецепты ─────────

  Future<List<Recipe>> loadRecipes() async {
    final p = await _p();
    final raw = p.getString(_kRecipes);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    final p = await _p();
    final raw = jsonEncode(recipes.map((e) => e.toJson()).toList());
    await p.setString(_kRecipes, raw);
  }

  // ───────── Категории ─────────

  Future<List<Category>> loadCategories() async {
    final p = await _p();
    final raw = p.getString(_kCategories);
    if (raw == null || raw.isEmpty) return defaultCategories;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return defaultCategories;
    }
  }

  Future<void> saveCategories(List<Category> categories) async {
    final p = await _p();
    final raw = jsonEncode(categories.map((e) => e.toJson()).toList());
    await p.setString(_kCategories, raw);
  }

    // ───────── Справочник ингредиентов ─────────

  Future<List<String>> loadIngredientNames() async {
    final p = await _p();
    final raw = p.getStringList(_kIngredientNames) ?? [];
    return raw;
  }

  Future<void> saveIngredientNames(List<String> names) async {
    final p = await _p();
    final cleaned = names
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    await p.setStringList(_kIngredientNames, cleaned);
  }

  /// Добавляет новые названия к справочнику.
  Future<void> mergeIngredientNames(Iterable<String> names) async {
    final current = await loadIngredientNames();
    final set = {...current};
    for (final n in names) {
      final t = n.trim();
      if (t.isNotEmpty) set.add(t);
    }
    await saveIngredientNames(set.toList());
  }

  // ───────── Справочник единиц ─────────

  static const List<String> defaultUnits = [
    'г',
    'кг',
    'мл',
    'л',
    'шт',
    'ст.л.',
    'ч.л.',
    'щепотка',
    'по вкусу',
  ];

  Future<List<String>> loadIngredientUnits() async {
    final p = await _p();
    final raw = p.getStringList(_kIngredientUnits);
    if (raw == null) return List.of(defaultUnits);
    return raw;
  }

  Future<void> saveIngredientUnits(List<String> units) async {
    final p = await _p();
    final cleaned = units
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    await p.setStringList(_kIngredientUnits, cleaned);
  }

  Future<void> mergeIngredientUnits(Iterable<String> units) async {
    final current = await loadIngredientUnits();
    final set = {...current};
    for (final u in units) {
      final t = u.trim();
      if (t.isNotEmpty) set.add(t);
    }
    await saveIngredientUnits(set.toList());
  }

  // ───────── Тема ─────────

  Future<String?> loadThemeMode() async {
    final p = await _p();
    return p.getString(_kThemeMode);
  }

  Future<void> saveThemeMode(String mode) async {
    final p = await _p();
    await p.setString(_kThemeMode, mode);
  }

  // ───────── Категории по умолчанию ─────────

  static final List<Category> defaultCategories = [
    Category(id: 'soup', name: 'Супы', icon: 'soup_kitchen'),
    Category(id: 'salad', name: 'Салаты', icon: 'eco'),
    Category(id: 'main', name: 'Горячее', icon: 'dinner_dining'),
    Category(id: 'dessert', name: 'Десерты', icon: 'cake'),
    Category(id: 'drink', name: 'Напитки', icon: 'local_cafe'),
    Category(id: 'bakery', name: 'Выпечка', icon: 'bakery_dining'),
    Category(id: 'other', name: 'Другое', icon: 'restaurant'),
  ];
}

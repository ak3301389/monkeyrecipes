import 'package:dio/dio.dart';

import 'dart:typed_data';

import 'photo_service.dart';

import 'package:recipe_scraper/recipe_scraper.dart' as rs;

import '../models.dart';
import 'iamcook_parser.dart';

/// Сервис импорта рецептов по ссылке.
class RecipeImportService {
  RecipeImportService._();
  static final RecipeImportService instance = RecipeImportService._();

  /// Загружает рецепт по URL и преобразует его в наш Recipe.
  Future<Recipe> importFromUrl(String url) async {
    // iamcook парсим своим парсером — у них нет JSON-LD с ингредиентами и шагами.
    if (IamcookParser.matches(url)) {
      final resp = await Dio().get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final recipe = IamcookParser.parse(url, resp.data ?? '');
      return await _downloadPhotos(recipe);
    }

    final scraped = await rs.scrapeRecipe(url);
    if (scraped == null) {
      throw Exception('Не удалось найти рецепт на странице');
    }

    final title = scraped.title.trim();
    if (title.isEmpty) {
      throw Exception('Не удалось найти название рецепта');
    }

    // Ингредиенты — пакет уже разобрал их на name/quantity/unit.
    final ingredients = <Ingredient>[];
    for (final ing in scraped.ingredients) {
      if (ing.name.trim().isEmpty) continue;
      ingredients.add(
        Ingredient(
          name: ing.name.trim(),
          amount: ing.quantity.toDouble(),
          unit: (ing.unit ?? '').trim(),
        ),
      );
    }

    // Шаги.
    final steps = <RecipeStep>[];
    for (final raw in scraped.instructions) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      steps.add(RecipeStep(text: text));
    }

    // Время.
    final minutes = _parseMinutes(scraped.totalTime);

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      cookingMinutes: minutes,
      ingredients: ingredients,
      steps: steps,
      photos: const [],
      notes: 'Импортировано с $url',
    );
  }

  /// Парсит строку времени ("1 ч. 35 мин.") в минуты.
  static int _parseMinutes(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    final s = raw.toLowerCase();

    int total = 0;
    final hours = RegExp(r'(\d+)\s*(ч|час)').firstMatch(s);
    if (hours != null) {
      total += (int.tryParse(hours.group(1)!) ?? 0) * 60;
    }
    final mins = RegExp(r'(\d+)\s*(м|мин)').firstMatch(s);
    if (mins != null) {
      total += int.tryParse(mins.group(1)!) ?? 0;
    }
    if (total == 0) {
      final n = int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '');
      if (n != null) total = n;
    }
    return total;
  }

  /// Скачивает все фото (рецепта и шагов) и заменяет URL на data-URL.
  Future<Recipe> _downloadPhotos(Recipe recipe) async {
    final dio = Dio();

    Future<String?> fetchDataUrl(String? url) async {
      if (url == null || url.isEmpty) return null;
      if (PhotoService.instance.isDataUrl(url)) return url;
      try {
        final resp = await dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (resp.data == null) return null;
        final compressed = await PhotoService.instance.compress(
          Uint8List.fromList(resp.data!),
        );
        return PhotoService.instance.bytesToDataUrl(compressed);
      } catch (_) {
        return null;
      }
    }

    // Главные фото.
    final photos = <String>[];
    for (final url in recipe.photos) {
      final dataUrl = await fetchDataUrl(url);
      if (dataUrl != null) photos.add(dataUrl);
    }

    // Фото шагов.
    final steps = <RecipeStep>[];
    for (final step in recipe.steps) {
      final dataUrl = await fetchDataUrl(step.photoUrl);
      steps.add(RecipeStep(text: step.text, photoUrl: dataUrl));
    }

    return Recipe(
      id: recipe.id,
      title: recipe.title,
      categoryId: recipe.categoryId,
      cookingMinutes: recipe.cookingMinutes,
      ingredients: recipe.ingredients,
      steps: steps,
      favorite: recipe.favorite,
      photos: photos,
      notes: recipe.notes,
    );
  }
}

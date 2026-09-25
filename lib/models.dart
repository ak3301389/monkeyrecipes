import 'dart:convert';

/// Ингредиент рецепта.
class Ingredient {
  String name;
  double amount;
  String unit;

  Ingredient({required this.name, this.amount = 0, this.unit = ''});

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
  };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    name: json['name'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    unit: json['unit'] as String? ?? '',
  );
}

/// Шаг приготовления.
class RecipeStep {
  String text;
  String? photoUrl;

  RecipeStep({required this.text, this.photoUrl});

  Map<String, dynamic> toJson() => {
    'text': text,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    text: json['text'] as String? ?? '',
    photoUrl: json['photoUrl'] as String?,
  );
}

/// Категория рецепта.
class Category {
  String id;
  String name;
  String icon; // имя иконки Material

  Category({required this.id, required this.name, this.icon = 'restaurant'});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon};

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    icon: json['icon'] as String? ?? 'restaurant',
  );
}

/// Рецепт.
class Recipe {
  String id;
  String title;
  String categoryId;
  int cookingMinutes;
  List<Ingredient> ingredients;
  List<RecipeStep> steps;
  bool favorite;
  List<String> photos; // data-URL или локальные пути
  String notes;

  Recipe({
    required this.id,
    required this.title,
    this.categoryId = '',
    this.cookingMinutes = 0,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    this.favorite = false,
    List<String>? photos,
    this.notes = '',
  }) : ingredients = ingredients ?? [],
       steps = steps ?? [],
       photos = photos ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'cookingMinutes': cookingMinutes,
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'steps': steps.map((e) => e.toJson()).toList(),
    'favorite': favorite,
    'photos': photos,
    'notes': notes,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Миграция со старого формата: photoUrl (String?) -> photos (List<String>).
    List<String> photos;
    final rawPhotos = json['photos'];
    if (rawPhotos is List) {
      photos = rawPhotos.whereType<String>().toList();
    } else {
      final legacy = json['photoUrl'] as String?;
      photos = (legacy == null || legacy.isEmpty) ? [] : [legacy];
    }

    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      cookingMinutes: (json['cookingMinutes'] as num?)?.toInt() ?? 0,
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      favorite: json['favorite'] as bool? ?? false,
      photos: photos,
      notes: json['notes'] as String? ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Recipe.fromJsonString(String source) =>
      Recipe.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

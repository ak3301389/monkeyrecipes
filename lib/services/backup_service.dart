import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';
import 'storage_service.dart';

/// Синхронизация данных с Firestore.
/// Всё хранится под users/{uid}/data/{collection}.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _dataDoc() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('data').doc('main');
  }

  /// Сохранить всё в Firestore.
  Future<void> saveAll() async {
    final doc = _dataDoc();
    if (doc == null) return;

    final s = StorageService.instance;
    final recipes = await s.loadRecipes();
    final categories = await s.loadCategories();
    final shopping = await s.loadShoppingItems();
    final ingredientNames = await s.loadIngredientNames();
    final ingredientUnits = await s.loadIngredientUnits();

    await doc.set({
      'recipes': recipes.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'shopping': shopping.map((e) => e.toJson()).toList(),
      'ingredientNames': ingredientNames,
      'ingredientUnits': ingredientUnits,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Загрузить всё из Firestore в локальное хранилище.
  /// Возвращает true, если данные были и загрузились.
  Future<bool> loadAll() async {
    final doc = _dataDoc();
    if (doc == null) return false;

    final snap = await doc.get();
    if (!snap.exists) return false;

    final data = snap.data();
    if (data == null) return false;

    final s = StorageService.instance;

    final recipes =
        (data['recipes'] as List<dynamic>?)
            ?.map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final categories =
        (data['categories'] as List<dynamic>?)
            ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final shopping =
        (data['shopping'] as List<dynamic>?)
            ?.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final ingredientNames =
        (data['ingredientNames'] as List<dynamic>?)?.cast<String>().toList() ??
        [];
    final ingredientUnits =
        (data['ingredientUnits'] as List<dynamic>?)?.cast<String>().toList() ??
        [];

    await s.saveRecipes(recipes);
    await s.saveCategories(categories);
    await s.saveShoppingItems(shopping);
    await s.saveIngredientNames(ingredientNames);
    await s.saveIngredientUnits(ingredientUnits);

    return true;
  }

  /// true, если в Firestore уже есть данные пользователя.
  Future<bool> hasCloudData() async {
    final doc = _dataDoc();
    if (doc == null) return false;
    final snap = await doc.get();
    return snap.exists;
  }
}

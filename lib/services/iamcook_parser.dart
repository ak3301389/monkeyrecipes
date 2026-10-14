import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import '../models.dart';

/// Парсер рецептов с iamcook.ru (у сайта нет JSON-LD с ингредиентами и шагами).
class IamcookParser {
  IamcookParser._();

  /// Проверяет, что URL — с iamcook.ru.
  static bool matches(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return false;
    return u.host.contains('iamcook.ru');
  }

  /// Парсит HTML и возвращает Recipe с заполненными полями.
  static Recipe parse(String url, String html) {
    final doc = html_parser.parse(html);

    final title = _title(doc);
    if (title.isEmpty) {
      throw Exception('Не удалось найти название рецепта');
    }

    final ingredients = _ingredients(doc);
    final steps = _steps(doc);
    final mainPhoto = _mainPhoto(doc);
    final minutes = _minutes(doc);

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      cookingMinutes: minutes,
      ingredients: ingredients,
      steps: steps,
      photos: mainPhoto == null ? const [] : [mainPhoto],
      notes: 'Импортировано с $url',
    );
  }

  // ───── Заголовок ─────
  static String _title(dom.Document doc) {
    final h1 = doc.querySelector('#recbody h1');
    if (h1 != null) return h1.text.trim();
    final alt = doc.querySelector('h1');
    return alt?.text.trim() ?? '';
  }

  // ───── Ингредиенты ─────
  static List<Ingredient> _ingredients(dom.Document doc) {
    final result = <Ingredient>[];
    final nodes = doc.querySelectorAll('div.ingredients div.ilist p');
    for (final p in nodes) {
      final raw = p.text.trim();
      if (raw.isEmpty) continue;
      final parsed = _parseIngredient(raw);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  static Ingredient? _parseIngredient(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    String namePart = s;
    String amountPart = '';

    final separators = [' - ', ' – ', ' — ', ':'];
    for (final sep in separators) {
      final idx = s.indexOf(sep);
      if (idx > 0) {
        namePart = s.substring(0, idx).trim();
        amountPart = s.substring(idx + sep.length).trim();
        break;
      }
    }

    double amount = 0;
    final numMatch = RegExp(r'[\d]+([.,][\d]+)?').firstMatch(amountPart);
    if (numMatch != null) {
      final numStr = numMatch.group(0)!.replaceAll(',', '.');
      amount = double.tryParse(numStr) ?? 0;
    }

    String unit = '';
    if (numMatch != null) {
      unit = amountPart
          .substring(numMatch.end)
          .trim()
          .replaceAll(RegExp(r'^[\-\s]+'), '');
    } else {
      unit = amountPart;
    }

    return Ingredient(name: namePart, amount: amount, unit: unit);
  }

  // ───── Шаги ─────
  static List<RecipeStep> _steps(dom.Document doc) {
    final result = <RecipeStep>[];
    final container = doc.querySelector('div.instructions');
    if (container == null) return result;

    // Идём по детям по порядку: <p> — текст шага, <div class="primg"> — фото к предыдущему шагу.
    String? pendingStepText;
    String? pendingStepPhoto;

    void flush() {
      final t = pendingStepText?.trim() ?? '';
      if (t.isNotEmpty) {
        result.add(RecipeStep(text: t, photoUrl: pendingStepPhoto));
      }
      pendingStepText = null;
      pendingStepPhoto = null;
    }

    for (final node in container.nodes) {
      if (node is dom.Element) {
        if (node.localName == 'p') {
          final text = node.text.trim();
          if (text.isEmpty) continue;
          flush();
          pendingStepText = text;
        } else if (node.localName == 'div' && node.classes.contains('primg')) {
          final img = node.querySelector('img.photo');
          final src = img?.attributes['src'];
          if (src != null && src.isNotEmpty) {
            pendingStepPhoto = src;
          }
        }
      }
    }
    flush();

    return result;
  }

  // ───── Главное фото ─────
  static String? _mainPhoto(dom.Document doc) {
    final figure = doc.querySelector('figure img.resultphoto');
    if (figure != null) {
      final src = figure.attributes['src'];
      if (src != null && src.isNotEmpty) return src;
    }
    final result = doc.querySelector('img.result-photo');
    return result?.attributes['src'];
  }

  // ───── Время ─────
  static int _minutes(dom.Document doc) {
    final meta = doc.querySelector('ul.ilparams li.time meta');
    final iso = meta?.attributes['content'];
    if (iso == null || iso.isEmpty) return 0;
    return _iso8601ToMinutes(iso);
  }

  static int _iso8601ToMinutes(String iso) {
    final h = RegExp(r'(\d+)H').firstMatch(iso);
    final m = RegExp(r'(\d+)M').firstMatch(iso);
    var total = 0;
    if (h != null) total += (int.tryParse(h.group(1)!) ?? 0) * 60;
    if (m != null) total += int.tryParse(m.group(1)!) ?? 0;
    return total;
  }
}

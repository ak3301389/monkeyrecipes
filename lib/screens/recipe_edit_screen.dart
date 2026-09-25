import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/photo_service.dart';
import '../services/storage_service.dart';

/// Экран создания/редактирования рецепта.
/// Возвращает через Navigator.pop сохранённый Recipe или null.
class RecipeEditScreen extends StatefulWidget {
  final Recipe? initial;

  const RecipeEditScreen({super.key, this.initial});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _notesCtrl;

  List<Category> _categories = [];
  List<String> _ingredientNames = [];
  List<String> _ingredientUnits = [];
  String? _categoryId;
  bool _favorite = false;
  bool _saving = false;
  final List<String> _photos = []; // data-URL или локальные пути
  bool _photoBusy = false;

  late final List<Ingredient> _ingredients;
  final _ingredientNameCtrls = <TextEditingController>[];
  final _ingredientAmountCtrls = <TextEditingController>[];
  final _ingredientUnitCtrls = <TextEditingController>[];

  late final List<RecipeStep> _steps;
  final _stepCtrls = <TextEditingController>[];
  final _stepPhotos = <String?>[]; // data-URL или null
  bool _stepPhotoBusy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _minutesCtrl = TextEditingController(
      text: (r?.cookingMinutes ?? 0) > 0 ? r!.cookingMinutes.toString() : '',
    );
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _categoryId = r?.categoryId;
    _favorite = r?.favorite ?? false;
    _photos.addAll(r?.photos ?? []);
    _ingredients = List<Ingredient>.from(r?.ingredients ?? []);
    _steps = List<RecipeStep>.from(r?.steps ?? []);
    for (final s in _steps) {
      _stepCtrls.add(TextEditingController(text: s.text));
      _stepPhotos.add(s.photoUrl);
    }
    for (final ing in _ingredients) {
      _ingredientNameCtrls.add(TextEditingController(text: ing.name));
      _ingredientAmountCtrls.add(
        TextEditingController(text: ing.amount > 0 ? _trimNum(ing.amount) : ''),
      );
      _ingredientUnitCtrls.add(TextEditingController(text: ing.unit));
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final s = StorageService.instance;
    final cats = await s.loadCategories();
    final names = await s.loadIngredientNames();
    final units = await s.loadIngredientUnits();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _ingredientNames = names;
      _ingredientUnits = units;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _minutesCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _ingredientNameCtrls) {
      c.dispose();
    }
    for (final c in _ingredientAmountCtrls) {
      c.dispose();
    }
    for (final c in _ingredientUnitCtrls) {
      c.dispose();
    }
    for (final c in _stepCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Новый рецепт' : 'Редактирование'),
        actions: [
          IconButton(
            tooltip: _favorite ? 'Убрать из избранного' : 'В избранное',
            onPressed: () => setState(() => _favorite = !_favorite),
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _PhotoGalleryField(
                photos: _photos,
                busy: _photoBusy,
                onAdd: _pickPhoto,
                onRemove: _removePhoto,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Борщ',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Без категории'),
                  ),
                  ..._categories.map(
                    (c) => DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minutesCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Время приготовления (мин)',
                  hintText: '30',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return 'Введите число';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Заметки',
                  hintText: 'Советы, варианты, источники',
                ),
              ),
              const SizedBox(height: 20),
              _IngredientsSection(
                nameCtrls: _ingredientNameCtrls,
                amountCtrls: _ingredientAmountCtrls,
                unitCtrls: _ingredientUnitCtrls,
                knownNames: _ingredientNames,
                knownUnits: _ingredientUnits,
                onAdd: _addIngredient,
                onRemove: _removeIngredient,
              ),
              const SizedBox(height: 12),
              _StepsSection(
                stepCtrls: _stepCtrls,
                stepPhotos: _stepPhotos,
                photoBusy: _stepPhotoBusy,
                onAdd: _addStep,
                onRemove: _removeStep,
                onPickPhoto: _pickStepPhoto,
                onRemovePhoto: _removeStepPhoto,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Сохранение…' : 'Сохранить'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (picked == null) return;
      setState(() => _photoBusy = true);
      final bytes = await picked.readAsBytes();
      final compressed = await PhotoService.instance.compress(bytes);
      final dataUrl = PhotoService.instance.bytesToDataUrl(compressed);
      if (!mounted) return;
      setState(() {
        _photos.add(dataUrl);
        _photoBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoBusy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Не удалось выбрать фото: $e')));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final base = widget.initial;

    final ingredients = <Ingredient>[];
    for (var i = 0; i < _ingredientNameCtrls.length; i++) {
      final name = _ingredientNameCtrls[i].text.trim();
      if (name.isEmpty) continue;
      ingredients.add(
        Ingredient(
          name: name,
          amount:
              double.tryParse(
                _ingredientAmountCtrls[i].text.trim().replaceAll(',', '.'),
              ) ??
              0,
          unit: _ingredientUnitCtrls[i].text.trim(),
        ),
      );
    }

    final steps = <RecipeStep>[];
    for (var i = 0; i < _stepCtrls.length; i++) {
      final text = _stepCtrls[i].text.trim();
      if (text.isEmpty) continue;
      final photo = i < _stepPhotos.length ? _stepPhotos[i] : null;
      steps.add(RecipeStep(text: text, photoUrl: photo));
    }

    final recipe = Recipe(
      id: base?.id ?? now,
      title: _titleCtrl.text.trim(),
      categoryId: _categoryId ?? '',
      cookingMinutes: int.tryParse(_minutesCtrl.text.trim()) ?? 0,
      ingredients: ingredients,
      steps: steps,
      favorite: _favorite,
      photos: List<String>.from(_photos),
      notes: _notesCtrl.text.trim(),
    );

    final s = StorageService.instance;
    await s.mergeIngredientNames(ingredients.map((e) => e.name));
    await s.mergeIngredientUnits(
      ingredients.map((e) => e.unit).where((u) => u.isNotEmpty),
    );

    if (!mounted) return;
    Navigator.of(context).pop(recipe);
  }

  void _addIngredient() {
    setState(() {
      _ingredientNameCtrls.add(TextEditingController());
      _ingredientAmountCtrls.add(TextEditingController());
      _ingredientUnitCtrls.add(TextEditingController());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredientNameCtrls.removeAt(index).dispose();
      _ingredientAmountCtrls.removeAt(index).dispose();
      _ingredientUnitCtrls.removeAt(index).dispose();
    });
  }

  void _addStep() {
    setState(() {
      _stepCtrls.add(TextEditingController());
      _stepPhotos.add(null);
    });
  }

  void _removeStep(int index) {
    setState(() {
      _stepCtrls.removeAt(index).dispose();
      _stepPhotos.removeAt(index);
    });
  }

  Future<void> _pickStepPhoto(int index) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (picked == null) return;
      setState(() => _stepPhotoBusy = true);
      final bytes = await picked.readAsBytes();
      final compressed = await PhotoService.instance.compress(bytes);
      final dataUrl = PhotoService.instance.bytesToDataUrl(compressed);
      if (!mounted) return;
      setState(() {
        _stepPhotos[index] = dataUrl;
        _stepPhotoBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _stepPhotoBusy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Не удалось выбрать фото: $e')));
    }
  }

  void _removeStepPhoto(int index) {
    setState(() => _stepPhotos[index] = null);
  }
}

class _IngredientsSection extends StatelessWidget {
  final List<TextEditingController> nameCtrls;
  final List<TextEditingController> amountCtrls;
  final List<TextEditingController> unitCtrls;
  final List<String> knownNames;
  final List<String> knownUnits;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _IngredientsSection({
    required this.nameCtrls,
    required this.amountCtrls,
    required this.unitCtrls,
    required this.knownNames,
    required this.knownUnits,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Ингредиенты',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Добавить ингредиент',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (nameCtrls.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Ингредиентов пока нет',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          ...List.generate(nameCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _IngredientNameField(
                      controller: nameCtrls[i],
                      suggestions: knownNames,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: amountCtrls[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Кол-во',
                        hintText: '2',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _IngredientUnitField(
                      controller: unitCtrls[i],
                      suggestions: knownUnits,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Удалить',
                    onPressed: () => onRemove(i),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _StepsSection extends StatelessWidget {
  final List<TextEditingController> stepCtrls;
  final List<String?> stepPhotos;
  final bool photoBusy;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index) onPickPhoto;
  final void Function(int index) onRemovePhoto;

  const _StepsSection({
    required this.stepCtrls,
    required this.stepPhotos,
    required this.photoBusy,
    required this.onAdd,
    required this.onRemove,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Шаги приготовления',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Добавить шаг',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (stepCtrls.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Шагов пока нет',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          ...List.generate(stepCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14, right: 4),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: scheme.secondaryContainer,
                          child: Text(
                            '${i + 1}',
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: stepCtrls[i],
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Опишите шаг',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Удалить',
                        onPressed: () => onRemove(i),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: _StepPhotoRow(
                      photo: stepPhotos[i],
                      busy: photoBusy,
                      onPick: () => onPickPhoto(i),
                      onRemove: () => onRemovePhoto(i),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _StepPhotoRow extends StatelessWidget {
  final String? photo;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _StepPhotoRow({
    required this.photo,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (photo == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: const Text('Добавить фото'),
        ),
      );
    }
    final bytes = PhotoService.instance.isDataUrl(photo!)
        ? PhotoService.instance.dataUrlToBytes(photo!)
        : null;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: bytes == null
              ? Container(
                  width: 72,
                  height: 72,
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                )
              : Image.memory(
                  bytes,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Заменить'),
        ),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Удалить'),
        ),
      ],
    );
  }
}

/// Галерея фото рецепта: сетка миниатюр + добавление + удаление.
class _PhotoGalleryField extends StatelessWidget {
  final List<String> photos;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _PhotoGalleryField({
    required this.photos,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final bytes = _decode(photos[i]);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: bytes == null
                          ? Container(
                              width: 120,
                              height: 120,
                              color: scheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_outlined),
                            )
                          : Image.memory(
                              bytes,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: scheme.surface.withValues(alpha: 0.85),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove(i),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: busy ? null : onAdd,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined),
          label: Text(photos.isEmpty ? 'Добавить фото' : 'Добавить ещё'),
        ),
      ],
    );
  }

  static Uint8List? _decode(String url) {
    if (PhotoService.instance.isDataUrl(url)) {
      return PhotoService.instance.dataUrlToBytes(url);
    }
    return null;
  }
}

/// Поле «Название ингредиента» с живым поиском по справочнику.
class _IngredientNameField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;

  const _IngredientNameField({
    required this.controller,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(q)).take(8);
      },
      onSelected: (value) => controller.text = value,
      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
        return TextField(
          controller: ctrl,
          focusNode: focus,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'Название',
            hintText: 'Свёкла',
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final scheme = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: scheme.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Поле «Единица измерения» с выпадающим списком из справочника.
class _IngredientUnitField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;

  const _IngredientUnitField({
    required this.controller,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return suggestions;
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: (value) => controller.text = value,
      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
        return TextField(
          controller: ctrl,
          focusNode: focus,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'Ед.',
            hintText: 'шт',
            suffixIcon: Icon(Icons.arrow_drop_down, size: 20),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final scheme = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: scheme.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

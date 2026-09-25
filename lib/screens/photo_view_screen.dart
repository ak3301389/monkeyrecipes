import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Полноэкранный просмотр фото.
///
/// Web: миниатюры снизу, клик по миниатюре — переключение,
///      колесо — зум, кнопка «×» — выход.
/// Android: свайп — листание, щипок — зум, тап по фото — выход.
class PhotoViewScreen extends StatefulWidget {
  final List<Uint8List> photos;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late final PageController _ctrl;
  late int _index;
  final _thumbCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: kIsWeb ? _buildWebBody() : _buildMobileBody(),
      ),
    );
  }

  // ───────── Web: без свайпа, миниатюры снизу, колесо = зум ─────────
  Widget _buildWebBody() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: _buildMainPhoto(),
          ),
        ),
        if (widget.photos.length > 1) _buildThumbnails(),
      ],
    );
  }

  // ───────── Mobile: свайп листает, тап выходит ─────────
  Widget _buildMobileBody() {
    return PageView.builder(
      controller: _ctrl,
      itemCount: widget.photos.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.memory(widget.photos[i], fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  // ───────── Основное фото ─────────
  Widget _buildMainPhoto() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.memory(widget.photos[_index], fit: BoxFit.contain),
      ),
    );
  }

  // ───────── Миниатюры (только Web) ─────────
  Widget _buildThumbnails() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          controller: _thumbCtrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.photos.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: i == _index ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        widget.photos[i],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

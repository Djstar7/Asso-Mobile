import 'package:flutter/material.dart';

import '../utils/app_theme_system.dart';

typedef ProductImageBuilder = Widget Function(String image, BoxFit fit);

/// Visionneuse plein écran : pincer / double-tap pour zoomer, balayer pour changer
/// de photo, vignettes pour sauter directement à une image.
class ProductImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final ProductImageBuilder imageBuilder;

  const ProductImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.imageBuilder,
  });

  /// Ouvre la visionneuse et renvoie l'index de la dernière photo consultée.
  static Future<int?> open(
    BuildContext context, {
    required List<String> images,
    required int initialIndex,
    required ProductImageBuilder imageBuilder,
  }) {
    return Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => ProductImageViewer(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
          imageBuilder: imageBuilder,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer> {
  late final PageController _pageController;
  late final ScrollController _thumbController;
  late int _index;
  bool _zoomed = false;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _thumbController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThumb());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _centerThumb() {
    if (!_thumbController.hasClients) return;
    const itemExtent = 64.0;
    final width = MediaQuery.of(context).size.width;
    final target = (_index * itemExtent) - (width / 2) + itemExtent / 2;
    _thumbController.animateTo(
      target.clamp(0, _thumbController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                _centerThumb();
              },
              itemBuilder: (_, index) => _ZoomableImage(
                onZoomChanged: (zoomed) {
                  if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                },
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                onSwipeDown: _close,
                child: widget.imageBuilder(widget.images[index], BoxFit.contain),
              ),
            ),

            // Barre supérieure
            AnimatedOpacity(
              opacity: _chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Fermer',
                            onPressed: _close,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const Spacer(),
                          if (multiple)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_index + 1} / ${widget.images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Vignettes + aide
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _chromeVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (multiple)
                            SizedBox(
                              height: 64,
                              child: ListView.builder(
                                controller: _thumbController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                itemCount: widget.images.length,
                                itemBuilder: (_, index) => GestureDetector(
                                  onTap: () => _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 56,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: index == _index
                                            ? AppThemeSystem.primaryColor
                                            : Colors.white24,
                                        width: index == _index ? 2.5 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Opacity(
                                        opacity: index == _index ? 1 : 0.6,
                                        child: widget.imageBuilder(
                                          widget.images[index],
                                          BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Text(
                              _zoomed
                                  ? 'Double-tapez pour revenir à la taille normale'
                                  : 'Pincez ou double-tapez pour zoomer',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;
  final VoidCallback onSwipeDown;

  const _ZoomableImage({
    required this.child,
    required this.onZoomChanged,
    required this.onTap,
    required this.onSwipeDown,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _animation;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;
  double _dragOffset = 0;

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          if (_zoomAnimation != null) _transform.value = _zoomAnimation!.value;
        });
    _transform.addListener(() => widget.onZoomChanged(_isZoomed));
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const scale = 2.5;
      target = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (scale - 1),
          -position.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoomAnimation = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      // Glisser vers le bas (sans zoom) ferme la visionneuse.
      onVerticalDragUpdate: _isZoomed
          ? null
          : (d) => setState(
              () => _dragOffset = (_dragOffset + d.delta.dy).clamp(0, 400),
            ),
      onVerticalDragEnd: _isZoomed
          ? null
          : (d) {
              if (_dragOffset > 120 || (d.primaryVelocity ?? 0) > 900) {
                widget.onSwipeDown();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: _dragOffset == 0 ? 180 : 0),
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Opacity(
          opacity: (1 - _dragOffset / 500).clamp(0.4, 1),
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            child: SizedBox.expand(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Bande de vignettes sous la photo principale d'une fiche produit.
class ProductThumbnailStrip extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ProductImageBuilder imageBuilder;

  const ProductThumbnailStrip({
    super.key,
    required this.images,
    required this.currentIndex,
    required this.onSelected,
    required this.imageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (images.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == currentIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppThemeSystem.primaryColor
                      : context.borderColor,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Opacity(
                  opacity: selected ? 1 : 0.7,
                  child: imageBuilder(images[index], BoxFit.cover),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

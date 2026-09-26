import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Vidéo en tête de la galerie d'une fiche produit.
///
/// Elle reprend là où la carte l'a laissée dans l'esprit de l'utilisateur :
/// elle démarre muette et en boucle dès qu'elle est à l'écran. Un bouton
/// active le son ; un toucher l'ouvre en plein écran, avec le son, sans la
/// recharger (le même lecteur est prêté à l'écran plein).
class ProductGalleryVideo extends StatefulWidget {
  const ProductGalleryVideo({
    super.key,
    required this.url,
    required this.poster,
    required this.active,
  });

  final String url;

  /// Affichée tant que la vidéo n'est pas prête.
  final Widget poster;

  /// Page affichée de la galerie : hors de cette page, la vidéo se met en pause.
  final bool active;

  @override
  State<ProductGalleryVideo> createState() => _ProductGalleryVideoState();
}

class _ProductGalleryVideoState extends State<ProductGalleryVideo>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  Future<void>? _initializing;
  bool _visible = false;
  bool _muted = true;
  bool _failed = false;
  bool _fullscreen = false;

  // Gardée en vie dans le PageView : revenir à la vidéo ne la recharge pas.
  @override
  bool get wantKeepAlive => true;

  bool get _shouldPlay => widget.active && _visible && !_fullscreen;

  @override
  void didUpdateWidget(covariant ProductGalleryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureController() {
    return _initializing ??= () async {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _controller = controller;
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(_muted ? 0 : 1);
      } catch (e) {
        debugPrint('[ProductGalleryVideo] lecture impossible : $e');
        _controller = null;
        controller.dispose();
        if (mounted) setState(() => _failed = true);
        return;
      }
      if (mounted) setState(() {});
    }();
  }

  Future<void> _sync() async {
    // Lecteur prêté au plein écran, qui recouvre la galerie : ne pas le
    // mettre en pause parce que la galerie n'est plus visible.
    if (_failed || _fullscreen) return;
    if (_shouldPlay) {
      await _ensureController();
      if (_shouldPlay) await _controller?.play();
    } else {
      await _controller?.pause();
    }
  }

  Future<void> _toggleSound() async {
    setState(() => _muted = !_muted);
    await _controller?.setVolume(_muted ? 0 : 1);
  }

  Future<void> _openFullscreen() async {
    if (_failed) return;
    await _ensureController();
    final controller = _controller;
    if (!mounted || controller == null) return;

    setState(() => _fullscreen = true);
    final unmuted = await ProductVideoFullscreen.open(
      context,
      controller: controller,
    );
    if (!mounted) return;
    // Le son choisi en plein écran reste : couper le son d'une vidéo que
    // l'on vient d'écouter serait déroutant.
    _muted = !(unmuted ?? false);
    await controller.setVolume(_muted ? 0 : 1);
    setState(() => _fullscreen = false);
    await _sync();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction >= 0.3;
        if (!mounted || visible == _visible) return;
        _visible = visible;
        _sync();
      },
      child: GestureDetector(
        onTap: _openFullscreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.poster,
            if (ready && !_fullscreen)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            // Invitation à regarder en grand, tant que la vidéo n'a pas démarré.
            if (!ready && !_failed) const Center(child: _PlayBadge(size: 64)),
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: false,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: AppDesign.accent,
                    bufferedColor: Colors.white.withValues(alpha: 0.35),
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            if (ready)
              Positioned(
                right: AppDesign.space3,
                top: AppDesign.space3 + MediaQuery.paddingOf(context).top,
                child: _RoundButton(
                  icon: _muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  tooltip: _muted ? 'Activer le son' : 'Couper le son',
                  onPressed: _toggleSound,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lecture en plein écran, avec le son et les commandes.
///
/// Emprunte le lecteur de la galerie : pas de second téléchargement, et la
/// lecture continue au même endroit. Renvoie vrai si le son est resté actif.
class ProductVideoFullscreen extends StatefulWidget {
  const ProductVideoFullscreen({super.key, required this.controller});

  final VideoPlayerController controller;

  static Future<bool?> open(
    BuildContext context, {
    required VideoPlayerController controller,
  }) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) =>
            ProductVideoFullscreen(controller: controller),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ProductVideoFullscreen> createState() => _ProductVideoFullscreenState();
}

class _ProductVideoFullscreenState extends State<ProductVideoFullscreen> {
  bool _controlsVisible = true;
  bool _muted = false;
  Timer? _hideTimer;

  VideoPlayerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // En plein écran, on veut entendre le vendeur.
    _c.setVolume(1);
    _c.play();
    _c.addListener(_onTick);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c.removeListener(_onTick);
    // Le lecteur appartient à la galerie : on le rend sans le libérer.
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    _c.value.isPlaying ? _c.pause() : _c.play();
    _scheduleHide();
  }

  void _toggleSound() {
    setState(() => _muted = !_muted);
    _c.setVolume(_muted ? 0 : 1);
    _scheduleHide();
  }

  String _format(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final value = _c.value;

    // Retour système : on rend le choix du son à la galerie, comme la croix.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(!_muted);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: value.isInitialized && value.aspectRatio > 0
                      ? value.aspectRatio
                      : 9 / 16,
                  child: VideoPlayer(_c),
                ),
              ),
              if (value.isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildControls(context, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, VideoPlayerValue value) {
    final caption = context.textStyle(
      FontSizeType.caption,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      // Voile sombre en haut et en bas : les commandes restent lisibles
      // sur une vidéo claire.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Colors.transparent, Color(0x99000000)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: AppDesign.space1,
              top: AppDesign.space1,
              child: AppBackButton(
                close: true,
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(!_muted),
              ),
            ),
            Positioned(
              right: AppDesign.space2,
              top: AppDesign.space1,
              child: _RoundButton(
                icon: _muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                tooltip: _muted ? 'Activer le son' : 'Couper le son',
                onPressed: _toggleSound,
              ),
            ),
            Center(
              child: _RoundButton(
                icon: value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                tooltip: value.isPlaying ? 'Pause' : 'Lecture',
                size: 64,
                onPressed: _togglePlay,
              ),
            ),
            Positioned(
              left: AppDesign.space4,
              right: AppDesign.space4,
              bottom: AppDesign.space4,
              child: Row(
                children: [
                  Text(_format(value.position), style: caption),
                  const SizedBox(width: AppDesign.space3),
                  Expanded(
                    child: VideoProgressIndicator(
                      _c,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDesign.space3,
                      ),
                      colors: VideoProgressColors(
                        playedColor: AppDesign.accent,
                        bufferedColor: Colors.white.withValues(alpha: 0.4),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDesign.space3),
                  Text(_format(value.duration), style: caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton rond translucide posé sur une vidéo.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          // Cible tactile d'au moins 48 px, même pour un bouton de 40.
          child: SizedBox(
            width: size < AppDesign.minTapTarget
                ? AppDesign.minTapTarget
                : size,
            height: size < AppDesign.minTapTarget
                ? AppDesign.minTapTarget
                : size,
            child: Icon(icon, color: Colors.white, size: size * 0.55),
          ),
        ),
      ),
    );
  }
}

/// Pastille « lecture » posée sur une affiche.
class _PlayBadge extends StatelessWidget {
  const _PlayBadge({this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

/// Pastille « ▶ 0:27 » des cartes vidéo, comme sur Pinterest.
class VideoDurationPill extends StatelessWidget {
  const VideoDurationPill({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesign.neutral900.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
          if (label != null) ...[
            const SizedBox(width: 2),
            Text(
              label!,
              style: context.textStyle(
                FontSizeType.caption,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

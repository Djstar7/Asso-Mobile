import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Un participant à la lecture automatique : une carte vidéo à l'écran.
abstract class AutoplayClient {
  /// Le coordinateur autorise (ou retire) la lecture.
  void setShouldPlay(bool shouldPlay);

  /// Libère le lecteur (décodeur, mémoire) : la carte n'est plus prioritaire.
  void release();
}

/// Répartit la lecture automatique entre les cartes visibles.
///
/// Seules les [maxPlaying] cartes les plus visibles jouent : un téléphone
/// n'a que quelques décodeurs vidéo, et chaque lecture consomme du forfait.
/// Les lecteurs mis en pause restent prêts ([maxAlive] au plus) pour repartir
/// sans nouveau téléchargement quand on remonte d'un cran.
class AutoplayCoordinator {
  AutoplayCoordinator({this.maxPlaying = 2, this.maxAlive = 4});

  static final AutoplayCoordinator instance = AutoplayCoordinator();

  /// Part visible à partir de laquelle une carte peut jouer.
  static const double playThreshold = 0.6;

  final int maxPlaying;
  final int maxAlive;

  final Map<AutoplayClient, double> _visibility = {};

  /// Lecteurs ouverts, du plus ancien au plus récemment joué.
  final List<AutoplayClient> _alive = [];

  @visibleForTesting
  Set<AutoplayClient> get playing => _playing;
  Set<AutoplayClient> _playing = {};

  void report(AutoplayClient client, double visibleFraction) {
    if (visibleFraction >= playThreshold) {
      _visibility[client] = visibleFraction;
    } else {
      _visibility.remove(client);
    }
    _rebalance();
  }

  /// Ferme tous les lecteurs à l'arrêt (mémoire faible, arrière-plan). Ceux
  /// qui jouent à l'écran sont gardés ; les autres se rouvriront au besoin.
  void releaseIdle() {
    for (final client in _alive.where((c) => !_playing.contains(c)).toList()) {
      _alive.remove(client);
      client.release();
    }
  }

  void remove(AutoplayClient client) {
    _visibility.remove(client);
    _alive.remove(client);
    _playing.remove(client);
    _rebalance();
  }

  void _rebalance() {
    final ranked = _visibility.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winners = ranked.take(maxPlaying).map((e) => e.key).toSet();

    for (final client in _playing.difference(winners)) {
      client.setShouldPlay(false);
    }
    for (final client in winners) {
      _alive
        ..remove(client)
        ..add(client);
      client.setShouldPlay(true);
    }
    _playing = winners;

    // Au-delà du quota, on ferme les lecteurs arrêtés depuis le plus longtemps.
    while (_alive.length > maxAlive) {
      final stale = _alive.firstWhere(
        (c) => !winners.contains(c),
        orElse: () => _alive.first,
      );
      _alive.remove(stale);
      stale.release();
    }
  }
}

/// Vidéo muette lue en boucle quand elle est à l'écran, comme sur Pinterest.
///
/// L'affiche ([poster]) reste dessous tant que la première image n'est pas
/// prête, puis la vidéo apparaît en fondu : jamais d'écran noir. Hors écran,
/// ou quand l'utilisateur a demandé moins d'animations, seule l'affiche est
/// montrée.
class AutoplayVideo extends StatefulWidget {
  const AutoplayVideo({
    super.key,
    required this.url,
    required this.poster,
    this.coordinator,
  });

  final String url;
  final Widget poster;

  /// Coordinateur partagé par défaut ; injectable pour les tests.
  final AutoplayCoordinator? coordinator;

  @override
  State<AutoplayVideo> createState() => _AutoplayVideoState();
}

class _AutoplayVideoState extends State<AutoplayVideo>
    implements AutoplayClient {
  VideoPlayerController? _controller;
  bool _shouldPlay = false;
  bool _ready = false;
  bool _failed = false;

  AutoplayCoordinator get _coordinator =>
      widget.coordinator ?? AutoplayCoordinator.instance;

  @override
  void didUpdateWidget(covariant AutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      release();
      _failed = false;
      if (_shouldPlay) _start();
    }
  }

  @override
  void dispose() {
    _coordinator.remove(this);
    _disposeController();
    super.dispose();
  }

  @override
  void setShouldPlay(bool shouldPlay) {
    if (!mounted || _shouldPlay == shouldPlay) return;
    _shouldPlay = shouldPlay;
    if (shouldPlay) {
      _start();
    } else {
      _controller?.pause();
    }
  }

  @override
  void release() {
    if (!mounted) return;
    _disposeController();
    setState(() => _ready = false);
  }

  Future<void> _start() async {
    if (_failed) return;
    final existing = _controller;
    if (existing != null) {
      if (existing.value.isInitialized) await existing.play();
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      // Ne coupe pas la musique de l'utilisateur : ces vidéos sont muettes.
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
    } catch (e) {
      // Lecteur libéré pendant le chargement (carte sortie de l'écran) : ce
      // n'est pas un échec, la vidéo repartira quand elle reviendra.
      if (!identical(_controller, controller)) return;
      debugPrint('[AutoplayVideo] lecture impossible (${widget.url}) : $e');
      _disposeController();
      _coordinator.remove(this);
      // L'affiche reste affichée : une vidéo illisible ne casse pas la carte.
      if (mounted) setState(() => _failed = true);
      return;
    }

    // Remplacé ou arrêté pendant le chargement.
    if (!mounted || !identical(_controller, controller)) return;
    if (_shouldPlay) await controller.play();
    if (mounted) setState(() => _ready = true);
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _ready = false;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Préférence système « réduire les animations » : on respecte, affiche seule.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final controller = _controller;

    final content = Stack(
      fit: StackFit.expand,
      children: [
        widget.poster,
        if (controller != null && _ready && controller.value.isInitialized)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 250),
            builder: (_, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
      ],
    );

    if (reduceMotion || _failed) return content;

    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: (info) {
        if (mounted) _coordinator.report(this, info.visibleFraction);
      },
      child: content,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/product_video_player.dart';
import '../../../data/models/real_estate_models.dart';

class ImmoRoomTourArgs {
  const ImmoRoomTourArgs({required this.title, required this.rooms, this.initialIndex = 0, this.initialMedia = 0});

  final String title;
  final List<RealEstateTourRoom> rooms;
  final int initialIndex;
  final int initialMedia;
}

/// Nom affiché d'une pièce : son libellé, sinon son type.
String immoRoomName(RealEstateTourRoom room) =>
    (room.label?.isNotEmpty ?? false) ? room.label! : 'immo.rooms.${room.kind}'.tr;

/// Visite pièce par pièce : la maison se parcourt comme on la visite, de
/// l'entrée à la cour, avec les photos (et la vidéo) de chaque pièce.
class ImmoRoomTourView extends StatefulWidget {
  const ImmoRoomTourView({super.key, required this.args});

  final ImmoRoomTourArgs args;

  @override
  State<ImmoRoomTourView> createState() => _ImmoRoomTourViewState();
}

class _ImmoRoomTourViewState extends State<ImmoRoomTourView> {
  late int _room = widget.args.initialIndex.clamp(0, widget.args.rooms.length - 1);
  late PageController _media = PageController(initialPage: widget.args.initialMedia);
  late int _mediaIndex = widget.args.initialMedia;

  List<RealEstateTourRoom> get _rooms => widget.args.rooms;

  void _goTo(int room) {
    if (room < 0 || room >= _rooms.length) return;
    setState(() {
      _room = room;
      _mediaIndex = 0;
      _media.dispose();
      _media = PageController();
    });
  }

  @override
  void dispose() {
    _media.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _rooms[_room];
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppDesign.neutral900,
      appBar: AppBar(
        backgroundColor: AppDesign.neutral900,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'common.close'.tr,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('immo.tour.title'.tr, style: context.textStyle(FontSizeType.caption, color: Colors.white70)),
            Text(widget.args.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _media,
                  itemCount: room.media.length,
                  onPageChanged: (i) => setState(() => _mediaIndex = i),
                  itemBuilder: (_, i) {
                    final media = room.media[i];
                    if (media.isVideo) {
                      return ProductGalleryVideo(
                        url: media.url,
                        active: i == _mediaIndex,
                        poster: media.posterUrl == null
                            ? const SizedBox.expand()
                            : AppNetworkImage(url: media.posterUrl!, decodeSize: size, fit: BoxFit.contain),
                      );
                    }
                    return InteractiveViewer(
                      child: Center(
                        child: AppNetworkImage(url: media.url, decodeSize: size, fit: BoxFit.contain),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: AppDesign.space2,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _Arrow(icon: Icons.chevron_left_rounded, onTap: _room > 0 ? () => _goTo(_room - 1) : null)),
                ),
                Positioned(
                  right: AppDesign.space2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(icon: Icons.chevron_right_rounded, onTap: _room < _rooms.length - 1 ? () => _goTo(_room + 1) : null),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppDesign.space4,
                  child: Column(
                    children: [
                      Text(
                        immoRoomName(room),
                        style: context.textStyle(FontSizeType.h6, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        'immo.tour.position'.trParams({
                          'room': '${_room + 1}',
                          'rooms': '${_rooms.length}',
                          'photo': '${_mediaIndex + 1}',
                          'photos': '${room.media.length}',
                        }),
                        style: context.textStyle(FontSizeType.body2, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppDesign.space3, vertical: AppDesign.space3),
                scrollDirection: Axis.horizontal,
                itemCount: _rooms.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppDesign.space2),
                itemBuilder: (_, i) {
                  final selected = i == _room;

                  return ChoiceChip(
                    label: Text(immoRoomName(_rooms[i])),
                    selected: selected,
                    onSelected: (_) => _goTo(i),
                    selectedColor: AppDesign.accent,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppDesign.neutral900, fontWeight: FontWeight.w600),
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? 0.25 : 0.9),
      shape: const CircleBorder(),
      child: IconButton(icon: Icon(icon, color: AppDesign.neutral900), onPressed: onTap),
    );
  }
}

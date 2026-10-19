import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../immo_actions.dart';
import '../immo_nav.dart';
import '../widgets/immo_widgets.dart';

/// Biens mis en favori, maisons et terrains confondus.
class ImmoFavoritesView extends StatefulWidget {
  const ImmoFavoritesView({super.key});

  @override
  State<ImmoFavoritesView> createState() => _ImmoFavoritesViewState();
}

class _ImmoFavoritesViewState extends State<ImmoFavoritesView> {
  List<RealEstateListing> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await RealEstateService.favorites();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _remove(RealEstateListing listing) async {
    await ImmoActions.toggleFavorite(context, listing);
    if (mounted) setState(() => _items = _items.where((l) => l.isFavorite).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? AppEmptyState(icon: Icons.favorite_border_rounded, title: 'immo.favorites.empty'.tr)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(context.ds.gutter, AppDesign.space4, context.ds.gutter, AppDesign.space8),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space4),
                    itemBuilder: (_, i) {
                      final listing = _items[i];
                      void open() => ImmoNav.push(ImmoNav.listing, arguments: listing.id).then((_) => _load());

                      return listing.isLand
                          ? ImmoLandCard(listing: listing, onTap: open, onFavorite: () => _remove(listing))
                          : ImmoHouseCard(listing: listing, onTap: open, onFavorite: () => _remove(listing));
                    },
                  ),
                ),
    );
  }
}

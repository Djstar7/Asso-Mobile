import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/product_service.dart';

/// Section « Produits importés » : Chine 🇨🇳, Turquie 🇹🇷, Dubaï 🇦🇪.
/// Filtre les produits par pays d'origine (origin_country).
class ImportView extends StatefulWidget {
  const ImportView({super.key});

  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportCountry {
  final String code; // ISO2 : CN, TR, AE
  final String name;
  final String flag;
  final List<Color> gradient;
  const _ImportCountry(this.code, this.name, this.flag, this.gradient);
}

class _ImportViewState extends State<ImportView> {
  static const _countries = [
    _ImportCountry('CN', 'Chine', '🇨🇳', [Color(0xFFDE2910), Color(0xFFFF6B4A)]),
    _ImportCountry('TR', 'Turquie', '🇹🇷', [Color(0xFFE30A17), Color(0xFFFF5C68)]),
    _ImportCountry('AE', 'Dubaï', '🇦🇪', [Color(0xFF00843D), Color(0xFF2FB56E)]),
  ];

  String _selected = 'CN';
  bool _loading = true;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ProductService.getProducts(originCountry: _selected, perPage: 30);
      final data = res.data?['data'];
      final list = (data is Map ? data['data'] : data) ?? [];
      _products = list is List ? list : [];
    } catch (_) {
      _products = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final country = _countries.firstWhere((c) => c.code == _selected);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(country)),
            SliverToBoxAdapter(child: _buildCountrySelector()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_products.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmpty(country))
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildProductCard(_products[i]),
                    childCount: _products.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_ImportCountry c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: c.gradient.first.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Text(c.flag, style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Produits importés',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Made in ${c.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildCountrySelector() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _countries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _countries[i];
          final selected = c.code == _selected;
          return GestureDetector(
            onTap: () {
              if (c.code != _selected) {
                setState(() => _selected = c.code);
                _load();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.gradient.first : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? c.gradient.first : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Text(c.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(c.name,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(_ImportCountry c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(c.flag, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text('Aucun produit importé de ${c.name} pour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
      ],
    );
  }

  Widget _buildProductCard(dynamic p) {
    final name = p['name']?.toString() ?? '';
    final price = p['price']?.toString() ?? '0';
    String? image;
    final primary = p['primary_image'] ?? p['primaryImage'];
    if (primary is Map) image = primary['url']?.toString() ?? primary['image_url']?.toString();
    image ??= (p['images'] is List && (p['images'] as List).isNotEmpty)
        ? ((p['images'][0] is Map) ? p['images'][0]['url']?.toString() : null)
        : null;

    return GestureDetector(
      onTap: () => Get.toNamed('/product', arguments: p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: image != null && image.isNotEmpty
                    ? Image.network(image, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPlaceholder())
                    : _imgPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('$price FCFA',
                      style: const TextStyle(color: Color(0xFFFF7900), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: Colors.grey.shade100,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 40),
      );
}

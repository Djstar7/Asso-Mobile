import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';

/// Licences d'une bibliothèque embarquée dans l'application.
class PackageLicenses {
  PackageLicenses(this.name);

  final String name;
  final List<LicenseEntry> entries = [];
}

/// Licences open source, aux couleurs de l'app (remplace la page Material).
class LicensesView extends StatefulWidget {
  const LicensesView({super.key, required this.appName, required this.version});

  final String appName;
  final String version;

  static void open({required String appName, required String version}) {
    Get.to(() => LicensesView(appName: appName, version: version));
  }

  @override
  State<LicensesView> createState() => _LicensesViewState();
}

class _LicensesViewState extends State<LicensesView> {
  late final Future<List<PackageLicenses>> _packages = _collect();
  String _query = '';

  static Future<List<PackageLicenses>> _collect() async {
    final byName = <String, PackageLicenses>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final name in entry.packages) {
        byName.putIfAbsent(name, () => PackageLicenses(name)).entries.add(entry);
      }
    }
    return byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'about.licenses.title'.tr,
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<PackageLicenses>>(
        future: _packages,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppThemeSystem.primaryColor,
                ),
              ),
            );
          }
          final all = snapshot.data!;
          final query = _query.trim().toLowerCase();
          final packages = query.isEmpty
              ? all
              : all.where((p) => p.name.toLowerCase().contains(query)).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.horizontalPadding,
              8,
              context.horizontalPadding,
              32,
            ),
            children: [
              _buildHeader(context, all.length),
              const SizedBox(height: 16),
              AppTextField(
                hint: 'about.licenses.search'.tr,
                prefixIcon: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              if (packages.isEmpty)
                AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'about.licenses.no_results'.tr,
                )
              else
                _buildList(context, packages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeSystem.primaryColor,
            AppThemeSystem.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: context.borderRadius(BorderRadiusType.medium),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.code_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.appName} · v${widget.version}',
                  style: context.h6.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'about.licenses.header'.trParams({'count': '$count'}),
                  style: context.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<PackageLicenses> packages) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < packages.length; i++) ...[
            if (i > 0) Divider(color: context.borderColor, height: 1),
            ListTile(
              title: Text(
                packages[i].name,
                style: context.body2.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'about.licenses.count'.trParams({
                  'count': '${packages[i].entries.length}',
                }),
                style: context.caption,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Get.to(
                () => _PackageLicensesView(package: packages[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Texte des licences d'une bibliothèque.
class _PackageLicensesView extends StatelessWidget {
  const _PackageLicensesView({required this.package});

  final PackageLicenses package;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          package.name,
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          8,
          context.horizontalPadding,
          32,
        ),
        itemCount: package.entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: context.borderRadius(BorderRadiusType.medium),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final paragraph in package.entries[index].paragraphs)
                Padding(
                  padding: EdgeInsets.only(
                    left: paragraph.indent == LicenseParagraph.centeredIndent
                        ? 0
                        : paragraph.indent * 16.0,
                    bottom: 8,
                  ),
                  child: Text(
                    paragraph.text,
                    textAlign:
                        paragraph.indent == LicenseParagraph.centeredIndent
                            ? TextAlign.center
                            : TextAlign.start,
                    style: context.caption.copyWith(
                      color: context.primaryTextColor,
                      height: 1.5,
                      fontWeight:
                          paragraph.indent == LicenseParagraph.centeredIndent
                              ? FontWeight.w600
                              : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

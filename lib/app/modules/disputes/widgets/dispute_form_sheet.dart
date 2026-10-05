import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/dispute_models.dart';

/// Ce que le client a saisi dans « Signaler un problème ».
class DisputeFormResult {
  final String reason;
  final String description;
  final List<XFile> photos;

  const DisputeFormResult({required this.reason, required this.description, required this.photos});
}

/// « Signaler un problème » : motif, explication libre et photos justificatives.
/// Sert aussi au signalement d'un produit de remplacement ([withReason] = false).
class DisputeFormSheet extends StatefulWidget {
  const DisputeFormSheet({super.key, required this.productName, this.withReason = true, this.title});

  final String productName;
  final bool withReason;
  final String? title;

  static Future<DisputeFormResult?> show({required String productName, bool withReason = true, String? title}) {
    return AppSheet.show<DisputeFormResult>(
      DisputeFormSheet(productName: productName, withReason: withReason, title: title),
    );
  }

  @override
  State<DisputeFormSheet> createState() => _DisputeFormSheetState();
}

class _DisputeFormSheetState extends State<DisputeFormSheet> {
  static const _maxPhotos = 6;

  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  String? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _valid => (!widget.withReason || _reason != null) && _description.text.trim().length >= 10;

  Future<void> _addPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(_maxPhotos - _photos.length)));
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return AppSheet(
      title: widget.title ?? 'disputes.form.title'.tr,
      subtitle: widget.productName,
      footer: AppButton(
        label: 'disputes.form.submit'.tr,
        icon: Icons.send_rounded,
        onPressed: _valid
            ? () => Navigator.of(context).pop(DisputeFormResult(
                  reason: _reason ?? 'other',
                  description: _description.text.trim(),
                  photos: List.of(_photos),
                ))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.withReason) ...[
            Text('disputes.form.reason'.tr, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDesign.space2),
            Wrap(
              spacing: AppDesign.space2,
              runSpacing: AppDesign.space2,
              children: disputeReasons
                  .map((reason) => ChoiceChip(
                        label: Text('disputes.reasons.$reason'.tr),
                        selected: _reason == reason,
                        selectedColor: AppDesign.accentSubtle,
                        onSelected: (_) => setState(() => _reason = reason),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppDesign.space4),
          ],
          Text('disputes.form.explain'.tr, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDesign.space2),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'disputes.form.explain_hint'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
            ),
          ),
          const SizedBox(height: AppDesign.space3),
          Text('disputes.form.photos'.tr, style: context.body2.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDesign.space2),
          Wrap(
            spacing: AppDesign.space2,
            runSpacing: AppDesign.space2,
            children: [
              ..._photos.asMap().entries.map((entry) => _PhotoThumb(
                    file: entry.value,
                    onRemove: () => setState(() => _photos.removeAt(entry.key)),
                  )),
              if (_photos.length < _maxPhotos)
                InkWell(
                  onTap: _addPhotos,
                  borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ds.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                      border: Border.all(color: ds.border),
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: ds.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDesign.space2),
          Text('disputes.form.funds_notice'.tr, style: context.caption.copyWith(color: ds.textSecondary)),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) => snapshot.hasData
                ? Image.memory(snapshot.data!, width: 72, height: 72, fit: BoxFit.cover)
                : const SizedBox(width: 72, height: 72),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 11,
              backgroundColor: AppDesign.danger,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

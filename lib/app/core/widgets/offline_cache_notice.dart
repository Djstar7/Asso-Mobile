import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// A stored balance or catalogue is a dated read-only copy.
class OfflineCacheNotice extends StatelessWidget {
  const OfflineCacheNotice({super.key, required this.savedAt});
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final date = savedAt;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              date == null
                  ? 'core.offline.no_saved_data'.tr
                  : 'core.offline.saved_copy'.trParams({
                      'date': DateFormat.yMd(
                        Get.locale?.toString(),
                      ).add_Hm().format(date.toLocal()),
                    }),
            ),
          ),
        ],
      ),
    );
  }
}

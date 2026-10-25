import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/services/firebase_messaging_service.dart';

class NotificationDigestView extends StatefulWidget {
  const NotificationDigestView({super.key, required this.date});
  final String date;
  @override
  State<NotificationDigestView> createState() => _NotificationDigestViewState();
}

class _NotificationDigestViewState extends State<NotificationDigestView> {
  final List<Map<String, dynamic>> _items = [];
  bool _busy = false;
  String? _error;
  int? _nextPage = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy || _nextPage == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ApiProvider.get(
        '/v1/notifications/digests/${widget.date}',
        queryParams: {'page': _nextPage},
      );
      if (!mounted) return;
      if (!response.success) {
        setState(() => _error = 'notification.digest.load_failed'.tr);
        return;
      }
      final data = response.data ?? {};
      setState(() {
        _items.addAll(
          (data['items'] as List? ?? []).whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
        _nextPage = int.tryParse('${data['next_page']}');
      });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'notification.digest.load_failed'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('notification.digest.title'.tr)),
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'notification.digest.date'.trParams({
              'date': DateFormat.yMd(
                Get.locale?.languageCode ?? 'fr',
              ).format(DateTime.parse(widget.date)),
            }),
          ),
        ),
        for (final item in _items)
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text('${item['title'] ?? ''}'),
            subtitle: Text('${item['body'] ?? ''}'),
            onTap: () => FirebaseMessagingService.to.openFromNotificationData(
              Map<String, dynamic>.from(item['data'] as Map? ?? {}),
            ),
          ),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        if (!_busy && _nextPage != null)
          TextButton(
            onPressed: _load,
            child: Text(
              (_error == null
                      ? 'notification.digest.more'
                      : 'notification.digest.retry')
                  .tr,
            ),
          ),
        if (!_busy && _items.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('notification.digest.empty'.tr),
          ),
      ],
    ),
  );
}

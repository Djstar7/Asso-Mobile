import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/controllers/app_config_controller.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/string_utils.dart';
import '../../../data/models/maritime.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/api_provider.dart';
import '../../../routes/app_pages.dart';

typedef MaritimeContactRequest = Future<ApiResponse> Function(int bookingId);
typedef MaritimeSupportUserIdLoader = Future<int?> Function();
typedef MaritimeSupportConversationRequest =
    Future<ApiResponse> Function(int supportUserId);
typedef MaritimeConversationNavigator =
    void Function(Map<String, dynamic> conversation);

/// Rubrique Maritime de Diaspo Exchange : départs à venir et envois de
/// l'utilisateur.
class MaritimeController extends GetxController {
  MaritimeController({
    MaritimeContactRequest? contactRequest,
    MaritimeSupportUserIdLoader? supportUserIdLoader,
    MaritimeSupportConversationRequest? supportConversationRequest,
    MaritimeConversationNavigator? conversationNavigator,
  }) : _contactRequest =
           contactRequest ?? ConversationService.contactMaritimeBooking,
       _supportUserIdLoader = supportUserIdLoader ?? _loadSupportUserId,
       _supportConversationRequest =
           supportConversationRequest ??
           ((supportUserId) =>
               ConversationService.startConversation(userId: supportUserId)),
       _conversationNavigator = conversationNavigator;

  final MaritimeService _service = Get.find<MaritimeService>();
  final MaritimeContactRequest _contactRequest;
  final MaritimeSupportUserIdLoader _supportUserIdLoader;
  final MaritimeSupportConversationRequest _supportConversationRequest;
  final MaritimeConversationNavigator? _conversationNavigator;

  /// 0 = Départs, 1 = Mes envois.
  final selectedTab = 0.obs;

  final departures = <MaritimeDeparture>[].obs;
  final departureSearchQuery = ''.obs;
  final bookableDeparturesOnly = false.obs;
  final myBookings = <MaritimeBooking>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final isLoadingBookings = false.obs;
  final error = RxnString();
  final contactingBookingIds = <int>{}.obs;
  final contactErrors = <int, String>{}.obs;

  int _page = 1;
  int _lastPage = 1;
  bool _loaded = false;
  String _transportMode = 'sea';
  int _generation = 0;

  List<MaritimeDeparture> get filteredDepartures {
    final query = departureSearchQuery.value.trim().toLowerCase();
    return departures.where((departure) {
      if (bookableDeparturesOnly.value && !departure.isBookable) return false;
      if (query.isEmpty) return true;

      final searchableText = [
        departure.partnerName,
        departure.originHub?.city,
        departure.originHub?.countryName,
        departure.originHub?.name,
        departure.destinationHub?.city,
        departure.destinationHub?.countryName,
        departure.destinationHub?.name,
      ].whereType<String>().join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  bool get hasMoreDepartures => _page < _lastPage;

  /// Chargé à la première ouverture de la rubrique, pas avant.
  void ensureLoaded({String transportMode = 'sea'}) {
    if (_loaded && _transportMode == transportMode) return;
    _loaded = true;
    _transportMode = transportMode;
    Future.microtask(loadDepartures);
  }

  Future<void> loadDepartures() async {
    final generation = ++_generation;
    isLoading.value = true;
    error.value = null;
    try {
      final result = await _service.getDepartures(
        transportMode: _transportMode,
      );
      if (generation != _generation) return;
      departures.assignAll(result.items);
      _page = 1;
      _lastPage = result.lastPage;
    } catch (e) {
      if (generation == _generation) {
        error.value = e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      if (generation == _generation) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || _page >= _lastPage) return;
    isLoadingMore.value = true;
    final generation = _generation;
    try {
      final result = await _service.getDepartures(
        page: _page + 1,
        transportMode: _transportMode,
      );
      if (generation != _generation) return;
      departures.addAll(result.items);
      _page++;
      _lastPage = result.lastPage;
    } catch (_) {
      // On réessaiera au prochain défilement.
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMyBookings() async {
    isLoadingBookings.value = true;
    try {
      myBookings.assignAll(await _service.getMyBookings());
    } catch (e) {
      error.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoadingBookings.value = false;
    }
  }

  void changeTab(int index) {
    selectedTab.value = index;
    if (index == 1) loadMyBookings();
  }

  Future<void> refreshAll() async {
    await (selectedTab.value == 0 ? loadDepartures() : loadMyBookings());
  }

  void openDeparture(MaritimeDeparture departure) {
    if (!departure.isBookable) {
      Get.snackbar(
        'maritime.trip_impossible_title'.tr,
        'maritime.trip_impossible'.tr,
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
      return;
    }
    Get.toNamed(Routes.MARITIME_BOOKING, arguments: {'departure': departure});
  }

  Future<void> cancelBooking(MaritimeBooking booking) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('maritime.cancel_title'.tr),
        content: Text('maritime.cancel_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('maritime.keep'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text('maritime.cancel_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.cancel(booking.id);
      Get.snackbar(
        'maritime.cancelled_title'.tr,
        'maritime.cancelled_message'.tr,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
      );
      loadMyBookings();
    } catch (e) {
      Get.snackbar(
        'maritime.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  Future<void> contactPlatform(MaritimeBooking booking) async {
    if (contactingBookingIds.contains(booking.id)) {
      return;
    }
    contactingBookingIds.add(booking.id);
    contactErrors.remove(booking.id);
    try {
      if (booking.status != 'shipped') {
        await _contactSupportForBooking(booking);
        return;
      }

      final response = await _contactRequest(booking.id);
      final body = response.data;
      final data = body?['data'];
      final conversationData = data is Map ? data['conversation'] : null;
      if (!response.success) {
        contactErrors[booking.id] = response.message;
        return;
      }
      if (conversationData is! Map) {
        contactErrors[booking.id] = 'maritime.contact_error'.tr;
        return;
      }

      final conversation = Map<String, dynamic>.from(conversationData);
      final conversationId = conversation['id'];
      if (conversationId == null) {
        contactErrors[booking.id] = 'maritime.contact_error'.tr;
        return;
      }
      final otherUser = conversation['other_user'];
      final otherUserData = otherUser is Map
          ? Map<String, dynamic>.from(otherUser)
          : <String, dynamic>{};
      final name =
          conversation['name']?.toString() ??
          conversation['title']?.toString() ??
          otherUserData['name']?.toString() ??
          'chatdetail.default_user_name'.tr;
      final args = <String, dynamic>{
        ...conversation,
        'id': conversationId,
        'name': name,
        'avatar':
            otherUserData['avatar']?.toString() ??
            (name.isNotEmpty ? name[0].toUpperCase() : 'A'),
        'isOnline': false,
        'is_support': true,
        'default_message': data['prefill_message']?.toString() ?? '',
      };
      if (_conversationNavigator case final navigator?) {
        navigator(args);
      } else {
        Get.toNamed(Routes.CHATDETAIL, arguments: args);
      }
    } catch (e) {
      contactErrors[booking.id] = e.toString().replaceAll('Exception: ', '');
    } finally {
      contactingBookingIds.remove(booking.id);
    }
  }

  Future<void> _contactSupportForBooking(MaritimeBooking booking) async {
    final supportUserId = await _supportUserIdLoader();
    if (supportUserId == null) {
      contactErrors[booking.id] = 'maritime.support_unavailable'.tr;
      return;
    }

    final response = await _supportConversationRequest(supportUserId);
    if (!response.success || response.data == null) {
      contactErrors[booking.id] = response.message.isNotEmpty
          ? response.message
          : 'maritime.contact_error'.tr;
      return;
    }

    final conversationData = response.data!['conversation'];
    if (conversationData is! Map || conversationData['id'] == null) {
      contactErrors[booking.id] = 'maritime.support_chat_unavailable'.tr;
      return;
    }

    final conversation = Map<String, dynamic>.from(conversationData);
    final appConfig = Get.isRegistered<AppConfigController>()
        ? Get.find<AppConfigController>()
        : null;
    final name = appConfig?.supportName ?? 'chatdetail.default_user_name'.tr;
    final route =
        '${booking.departure?.originHub?.city ?? ''} → '
        '${booking.departure?.destinationHub?.city ?? ''}';
    final args = <String, dynamic>{
      ...conversation,
      'id': conversation['id'].toString(),
      'name': name,
      'avatar': StringUtils.getInitials(name),
      'isOnline': false,
      'is_support': true,
      'default_message': 'maritime.contact_message'.trParams({
        'id': '${booking.id}',
        'route': route,
      }),
    };
    if (_conversationNavigator case final navigator?) {
      navigator(args);
    } else {
      Get.toNamed(Routes.CHATDETAIL, arguments: args);
    }
  }

  static Future<int?> _loadSupportUserId() async {
    final appConfig = Get.isRegistered<AppConfigController>()
        ? Get.find<AppConfigController>()
        : Get.put(AppConfigController(), permanent: true);
    return appConfig.ensureSupportUserId();
  }

  Future<void> reportLoss(MaritimeBooking booking) async {
    if (!booking.canReportLoss) return;
    final reasonController = TextEditingController();
    final reason = await Get.dialog<String>(
      AlertDialog(
        title: Text('maritime.claim.report_title'.tr),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'maritime.claim.reason'.tr,
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('common.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isNotEmpty) Get.back(result: value);
            },
            child: Text('maritime.claim.submit'.tr),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await _service.reportLoss(bookingId: booking.id, reason: reason);
      Get.snackbar(
        'maritime.claim.report_title'.tr,
        'maritime.claim.report_success'.tr,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
      );
      await loadMyBookings();
    } catch (e) {
      Get.snackbar(
        'maritime.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Montant exprimé dans [currency], affiché dans la devise de l'utilisateur.
  String formatAmount(double amount, String currency) =>
      CurrencyService.formatFromCurrency(amount, currency);

  String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String formatHistoryDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return raw;

    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

    final includesTime = raw.contains('T') || raw.contains(' ');
    final pattern = includesTime ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy';
    return DateFormat(
      pattern,
      Get.locale?.toString() ?? 'fr_FR',
    ).format(date.toLocal());
  }
}

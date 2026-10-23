import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../core/services/locale_service.dart';
import '../../core/values/constants.dart';
import '../models/maritime.dart';
import 'storage_service.dart';
import 'api_validation_exception.dart';

/// Diaspo Maritime : départs des partenaires maritimes et envois.
class MaritimeService extends GetxService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  @override
  void onInit() {
    super.onInit();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = StorageService.getToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          options.headers['Accept'] = 'application/json';
          options.headers['Accept-Language'] = LocaleService.currentLanguage;
          return handler.next(options);
        },
      ),
    );
  }

  /// Message d'erreur du serveur (422 métier ou validation), sinon l'erreur brute.
  Exception _error(Object e) {
    if (e is DioException && e.response?.data is Map) {
      final data = e.response!.data as Map;
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return Exception(
          first is List ? first.first.toString() : first.toString(),
        );
      }
      if (data['message'] != null) return Exception(data['message'].toString());
    }
    return e is Exception ? e : Exception(e.toString());
  }

  Future<({List<MaritimeDeparture> items, int lastPage})> getDepartures({
    int page = 1,
    String? originCountry,
    String? transportMode,
    String? destinationCountry,
  }) async {
    try {
      final response = await _dio.get(
        '/v1/maritime/departures',
        queryParameters: {
          'page': page,
          'transport_mode': ?transportMode,
          if (originCountry != null) 'origin_country': originCountry,
          if (destinationCountry != null)
            'destination_country': destinationCountry,
        },
      );
      final data = response.data['data'] as Map;
      final items = (data['data'] as List)
          .map((e) => MaritimeDeparture.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (
        items: items,
        lastPage: (data['last_page'] as num?)?.toInt() ?? 1,
      );
    } catch (e) {
      throw _error(e);
    }
  }

  Future<List<MaritimeBooking>> getMyBookings() async {
    try {
      final response = await _dio.get(
        '/v1/maritime/bookings',
        queryParameters: {'per_page': 50},
      );
      return ((response.data['data'] as Map)['data'] as List)
          .map((e) => MaritimeBooking.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw _error(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInquiries() async {
    try {
      final response = await _dio.get('/v1/maritime/inquiries');
      return (response.data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw _error(e);
    }
  }

  Future<Map<String, dynamic>> createInquiry(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/v1/maritime/inquiries', data: data);
      return Map<String, dynamic>.from(response.data['data']);
    } catch (e) {
      throw _error(e);
    }
  }

  Future<Map<String, dynamic>> acceptInquiry(
    Map<String, dynamic> inquiry,
  ) async {
    try {
      final response = await _dio.post(
        '/v1/maritime/inquiries/${inquiry['id']}/accept',
        data: {
          'expected_amount': inquiry['freight_amount'],
          'expected_currency': inquiry['currency'],
        },
      );
      return Map<String, dynamic>.from(response.data['data']);
    } catch (e) {
      throw _error(e);
    }
  }

  /// Crée l'envoi et lance l'encaissement. Renvoie l'envoi et le bloc `payment`.
  Future<({MaritimeBooking booking, Map<String, dynamic> payment})> book({
    required int departureId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/maritime/departures/$departureId/book',
        data: data,
      );
      return (
        booking: MaritimeBooking.fromJson(
          Map<String, dynamic>.from(response.data['data']),
        ),
        payment: Map<String, dynamic>.from(response.data['payment'] ?? {}),
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 422 && body is Map<String, dynamic>) {
        throw ApiValidationException.fromJson(body);
      }
      rethrow;
    }
  }

  /// État du paiement : `paid`, `failed` (avec le motif Mobile Money) ou `pending`.
  Future<({String status, String? failure})> paymentState(int bookingId) async {
    try {
      final response = await _dio.get(
        '/v1/maritime/bookings/$bookingId/payment-status',
      );
      final data = response.data['data'] ?? {};
      if (data['payment_status'] == 'completed')
        return (status: 'paid', failure: null);
      if (data['status'] == 'cancelled') {
        return (status: 'failed', failure: data['payment_failure']?.toString());
      }
      return (status: 'pending', failure: null);
    } catch (_) {
      return (status: 'pending', failure: null);
    }
  }

  Future<MaritimeBooking> cancel(int bookingId) async {
    try {
      final response = await _dio.post(
        '/v1/maritime/bookings/$bookingId/cancel',
      );
      return MaritimeBooking.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } catch (e) {
      throw _error(e);
    }
  }

  /// Enregistre la déclaration de perte, sans montant de remboursement fourni
  /// par le client : l'éligibilité et l'indemnisation sont déterminées serveur.
  Future<Map<String, dynamic>> reportLoss({
    required int bookingId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/maritime/bookings/$bookingId/loss-reports',
        data: {'reason': reason},
      );
      final data = response.data['data'];
      return data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
    } catch (e) {
      throw _error(e);
    }
  }
}

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:image_picker/image_picker.dart' show XFile;
import '../models/diaspo_offer.dart';
import '../models/diaspo_booking.dart';
import '../../core/values/constants.dart';
import 'storage_service.dart';

class DiaspoService extends GetxService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  @override
  void onInit() {
    super.onInit();
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
      onError: (error, handler) {
        print('❌ DIASPO SERVICE ERROR: ${error.message}');
        print('   Response: ${error.response?.data}');
        return handler.next(error);
      },
    ));
  }

  // ============================================
  // VERIFICATION
  // ============================================

  /// Upload verification document (CNI or Passport) - Recto/Verso
  ///
  /// Utilise des [XFile] et un upload via octets (`fromBytes`) afin d'être
  /// compatible mobile ET web (Chrome), où `dart:io File` n'existe pas.
  Future<Map<String, dynamic>> uploadVerificationDocument({
    required XFile frontImage,
    required XFile backImage,
    String documentType = 'cni', // 'cni' or 'passport'
  }) async {
    try {
      final frontFileName =
          frontImage.name.isNotEmpty ? frontImage.name : 'document_front.jpg';
      final backFileName =
          backImage.name.isNotEmpty ? backImage.name : 'document_back.jpg';

      FormData formData = FormData.fromMap({
        'document_front': MultipartFile.fromBytes(
          await frontImage.readAsBytes(),
          filename: frontFileName,
        ),
        'document_back': MultipartFile.fromBytes(
          await backImage.readAsBytes(),
          filename: backFileName,
        ),
        'document_type': documentType,
      });

      final response = await _dio.post(
        '/v1/diaspo/upload-verification',
        data: formData,
      );

      return response.data;
    } catch (e) {
      print('Error uploading verification document: $e');
      rethrow;
    }
  }

  /// Get verification status
  Future<Map<String, dynamic>> getVerificationStatus() async {
    try {
      final response = await _dio.get('/v1/diaspo/verification-status');
      return response.data;
    } catch (e) {
      print('Error getting verification status: $e');
      rethrow;
    }
  }

  // ============================================
  // OFFERS
  // ============================================

  /// Get all offers (with filters)
  Future<Map<String, dynamic>> getOffers({
    String? departureCountry,
    String? arrivalCountry,
    String? departureCity,
    String? arrivalCity,
    String? minDate,
    String? maxDate,
    double? maxPrice,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (departureCountry != null) queryParameters['departure_country'] = departureCountry;
      if (arrivalCountry != null) queryParameters['arrival_country'] = arrivalCountry;
      if (departureCity != null) queryParameters['departure_city'] = departureCity;
      if (arrivalCity != null) queryParameters['arrival_city'] = arrivalCity;
      if (minDate != null) queryParameters['min_date'] = minDate;
      if (maxDate != null) queryParameters['max_date'] = maxDate;
      if (maxPrice != null) queryParameters['max_price'] = maxPrice;

      final response = await _dio.get(
        '/v1/diaspo/offers',
        queryParameters: queryParameters,
      );

      return response.data;
    } catch (e) {
      print('Error getting offers: $e');
      rethrow;
    }
  }

  /// Get user's own offers
  Future<Map<String, dynamic>> getMyOffers({int page = 1, int perPage = 20}) async {
    try {
      final response = await _dio.get(
        '/v1/diaspo/offers/my-offers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );

      return response.data;
    } catch (e) {
      print('Error getting my offers: $e');
      rethrow;
    }
  }

  /// Get a single offer
  Future<DiaspoOffer> getOffer(int id) async {
    try {
      final response = await _dio.get('/v1/diaspo/offers/$id');
      return DiaspoOffer.fromJson(response.data['data']);
    } catch (e) {
      print('Error getting offer: $e');
      rethrow;
    }
  }

  /// Create a new offer
  Future<DiaspoOffer> createOffer({
    required String departureCountry,
    required String departureCity,
    required DateTime departureDateTime,
    required String arrivalCountry,
    required String arrivalCity,
    required DateTime arrivalDateTime,
    required double pricePerKg,
    required double availableKg,
    String currency = 'EUR',
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/offers',
        data: {
          'departure_country': departureCountry,
          'departure_city': departureCity,
          'departure_datetime': departureDateTime.toIso8601String(),
          'arrival_country': arrivalCountry,
          'arrival_city': arrivalCity,
          'arrival_datetime': arrivalDateTime.toIso8601String(),
          'price_per_kg': pricePerKg,
          'available_kg': availableKg,
          'currency': currency,
        },
      );

      return DiaspoOffer.fromJson(response.data['data']);
    } catch (e) {
      print('Error creating offer: $e');
      rethrow;
    }
  }

  /// Update an offer
  Future<DiaspoOffer> updateOffer(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/v1/diaspo/offers/$id', data: data);
      return DiaspoOffer.fromJson(response.data['data']);
    } catch (e) {
      print('Error updating offer: $e');
      rethrow;
    }
  }

  /// Delete an offer
  Future<void> deleteOffer(int id) async {
    try {
      final response = await _dio.delete('/v1/diaspo/offers/$id');

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Échec de la suppression');
      }
    } on DioException catch (e) {
      print('❌ Error deleting offer: ${e.message}');
      print('   Response: ${e.response?.data}');

      if (e.response?.data != null && e.response!.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('Impossible de supprimer l\'offre');
    } catch (e) {
      print('❌ Unexpected error deleting offer: $e');
      rethrow;
    }
  }

  // ============================================
  // BOOKINGS
  // ============================================

  /// Get all bookings
  Future<Map<String, dynamic>> getBookings({
    String? role, // 'buyer' or 'seller'
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (role != null) queryParameters['role'] = role;
      if (status != null) queryParameters['status'] = status;

      final response = await _dio.get(
        '/v1/diaspo/bookings',
        queryParameters: queryParameters,
      );

      return response.data;
    } catch (e) {
      print('Error getting bookings: $e');
      rethrow;
    }
  }

  /// Get a single booking
  Future<DiaspoBooking> getBooking(int id) async {
    try {
      final response = await _dio.get('/v1/diaspo/bookings/$id');
      return DiaspoBooking.fromJson(response.data['data']);
    } catch (e) {
      print('Error getting booking: $e');
      rethrow;
    }
  }

  /// Book kilos (create booking) — paiement KPay direct
  Future<DiaspoBooking> bookOffer({
    required int offerId,
    required double kgBooked,
    required String provider,    // code opérateur KPay (ex. MTN_MOMO_CMR)
    required String phoneNumber, // numéro international sans '+'
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/offers/$offerId/book',
        data: {
          'kg_booked': kgBooked,
          'provider': provider,
          'phone_number': phoneNumber,
          if (notes != null) 'notes': notes,
        },
      );

      return DiaspoBooking.fromJson(response.data['data']);
    } catch (e) {
      print('Error booking offer: $e');
      rethrow;
    }
  }

  /// Statut de paiement d'une réservation (re-vérifie chez KPay). Renvoie
  /// 'pending' | 'paid' | 'failed'.
  Future<String> bookingPaymentStatus(int bookingId) async {
    try {
      final response = await _dio.get('/v1/diaspo/bookings/$bookingId/payment-status');
      return response.data['data']?['payment_status']?.toString() ?? 'pending';
    } catch (e) {
      return 'pending';
    }
  }

  /// Confirm receipt with confirmation code
  Future<DiaspoBooking> confirmReceipt({
    required int bookingId,
    required String confirmationCode,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/bookings/$bookingId/confirm-receipt',
        data: {
          'confirmation_code': confirmationCode,
        },
      );

      return DiaspoBooking.fromJson(response.data['data']);
    } catch (e) {
      print('Error confirming receipt: $e');
      rethrow;
    }
  }

  /// Seller confirms delivery with confirmation code (unlocks funds)
  Future<DiaspoBooking> sellerConfirmDelivery({
    required int bookingId,
    required String confirmationCode,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/bookings/$bookingId/seller-confirm-code',
        data: {
          'confirmation_code': confirmationCode,
        },
      );

      return DiaspoBooking.fromJson(response.data['data']);
    } on DioException catch (e) {
      print('❌ Error confirming delivery: ${e.message}');
      print('   Response: ${e.response?.data}');

      if (e.response?.data != null && e.response!.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('Impossible de confirmer la livraison');
    } catch (e) {
      print('❌ Unexpected error confirming delivery: $e');
      rethrow;
    }
  }

  /// Seller confirms delivery using only confirmation code (finds booking automatically)
  Future<DiaspoBooking> confirmDeliveryByCode({
    required String confirmationCode,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/confirm-by-code',
        data: {
          'confirmation_code': confirmationCode,
        },
      );

      return DiaspoBooking.fromJson(response.data['data']);
    } on DioException catch (e) {
      print('❌ Error confirming delivery by code: ${e.message}');
      print('   Response: ${e.response?.data}');

      if (e.response?.data != null && e.response!.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('Impossible de confirmer la livraison avec ce code');
    } catch (e) {
      print('❌ Unexpected error confirming delivery by code: $e');
      rethrow;
    }
  }

  /// Cancel a booking
  Future<DiaspoBooking> cancelBooking({
    required int bookingId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/bookings/$bookingId/cancel',
        data: {
          'reason': reason,
        },
      );

      return DiaspoBooking.fromJson(response.data['data']);
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }
}

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:image_picker/image_picker.dart' show XFile;
import '../models/diaspo_offer.dart';
import '../models/diaspo_booking.dart';
import '../models/parcel_nature.dart';
import '../../core/values/constants.dart';
import 'storage_service.dart';
import '../../core/services/locale_service.dart';

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
        options.headers['Accept-Language'] = LocaleService.currentLanguage;
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

  /// Envoie les pièces du voyageur.
  ///
  /// Parcours renforcé : [nationality] et [residenceCountry] (codes ISO) fixent
  /// les pièces exigées par le serveur ; verso seulement pour une CNI, titre
  /// de séjour ou visa s'il vit hors de son pays, selfie pris en direct.
  ///
  /// Utilise des [XFile] et un upload via octets (`fromBytes`) afin d'être
  /// compatible mobile ET web (Chrome), où `dart:io File` n'existe pas.
  Future<Map<String, dynamic>> uploadVerificationDocument({
    required XFile frontImage,
    XFile? backImage,
    String documentType = 'cni', // 'cni' or 'passport'
    String? nationality,
    String? residenceCountry,
    String? residenceDocumentType, // 'residence_permit' | 'visa'
    XFile? residenceImage,
    XFile? selfie,
  }) async {
    try {
      Future<MultipartFile> part(XFile f, String fallback) async =>
          MultipartFile.fromBytes(
            await f.readAsBytes(),
            filename: f.name.isNotEmpty ? f.name : fallback,
          );

      FormData formData = FormData.fromMap({
        'document_front': await part(frontImage, 'document_front.jpg'),
        if (backImage != null)
          'document_back': await part(backImage, 'document_back.jpg'),
        'document_type': documentType,
        if (nationality != null) 'nationality': nationality,
        if (residenceCountry != null) 'residence_country': residenceCountry,
        if (residenceDocumentType != null)
          'residence_document_type': residenceDocumentType,
        if (residenceImage != null)
          'residence_document': await part(residenceImage, 'residence.jpg'),
        if (selfie != null) 'selfie': await part(selfie, 'selfie.jpg'),
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
    XFile? travelProof, // billet ou réservation (départ et destination)
  }) async {
    try {
      final fields = <String, dynamic>{
        'departure_country': departureCountry,
        'departure_city': departureCity,
        'departure_datetime': departureDateTime.toIso8601String(),
        'arrival_country': arrivalCountry,
        'arrival_city': arrivalCity,
        'arrival_datetime': arrivalDateTime.toIso8601String(),
        'price_per_kg': pricePerKg,
        'available_kg': availableKg,
        'currency': currency,
      };
      if (travelProof != null) {
        fields['travel_proof'] = MultipartFile.fromBytes(
          await travelProof.readAsBytes(),
          filename: travelProof.name.isNotEmpty ? travelProof.name : 'travel_proof.jpg',
        );
      }
      final response = await _dio.post(
        '/v1/diaspo/offers',
        data: travelProof != null ? FormData.fromMap(fields) : fields,
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
        throw Exception(response.data['message'] ?? 'data.diaspo.delete_failed'.tr);
      }
    } on DioException catch (e) {
      print('❌ Error deleting offer: ${e.message}');
      print('   Response: ${e.response?.data}');

      if (e.response?.data != null && e.response!.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      throw Exception('data.diaspo.delete_offer_error'.tr);
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

  // ============================================
  // ASSURANCE DES COLIS
  // ============================================

  /// Natures de colis assurables et seuil indicatif avion / maritime (kg).
  Future<({List<ParcelNature> natures, double airMaxKgHint})>
      getParcelNatures() async {
    final response = await _dio.get('/v1/diaspo/parcel-natures');
    final list = (response.data['data'] as List? ?? [])
        .map((e) => ParcelNature.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final hint = double.tryParse(
            response.data['meta']?['air_max_kg_hint']?.toString() ?? '') ??
        23;
    return (natures: list, airMaxKgHint: hint);
  }

  /// Supplément d'assurance calculé par le serveur, dans [currency].
  Future<double> insuranceQuote({
    required int natureId,
    required double declaredValue,
    required String declaredValueCurrency,
    required String currency,
  }) async {
    final response = await _dio.post('/v1/diaspo/insurance-quote', data: {
      'parcel_nature_id': natureId,
      'declared_value': declaredValue,
      'declared_value_currency': declaredValueCurrency,
      'currency': currency,
    });
    return double.tryParse(
            response.data['data']?['insurance_amount']?.toString() ?? '') ??
        0;
  }

  /// Crée une réservation et initie l'encaissement selon le moyen choisi.
  ///
  /// [paymentMethod] ∈ kpay | paypal | stripe. Pour kpay, [provider] (code
  /// opérateur) et [phoneNumber] sont requis. Renvoie un map contenant :
  ///   - 'booking' : DiaspoBooking
  ///   - 'payment' : bloc décrivant le sous-parcours (flow, approval_url, …)
  Future<Map<String, dynamic>> bookOffer({
    required int offerId,
    required double kgBooked,
    required String paymentMethod,
    String? provider,    // code opérateur KPay (ex. MTN_MOMO_CMR) — requis si kpay
    String? phoneNumber, // numéro international sans '+' — requis si kpay
    String? notes,
    int? parcelNatureId,
    double? declaredValue,
    String? declaredValueCurrency,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/diaspo/offers/$offerId/book',
        data: {
          'kg_booked': kgBooked,
          'payment_method': paymentMethod,
          if (provider != null) 'provider': provider,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (notes != null) 'notes': notes,
          if (parcelNatureId != null) 'parcel_nature_id': parcelNatureId,
          if (declaredValue != null) 'declared_value': declaredValue,
          if (declaredValueCurrency != null) 'declared_value_currency': declaredValueCurrency,
        },
      );

      return {
        'booking': DiaspoBooking.fromJson(response.data['data']),
        'payment': Map<String, dynamic>.from(response.data['payment'] ?? {}),
      };
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      if (msg != null) throw Exception(msg.toString());
      print('Error booking offer: ${e.message}');
      rethrow;
    } catch (e) {
      print('Error booking offer: $e');
      rethrow;
    }
  }

  /// Statut de paiement d'une réservation (re-vérifie côté serveur selon le rail).
  /// Normalise en 'pending' | 'paid' | 'failed'.
  Future<String> bookingPaymentStatus(int bookingId) async =>
      (await bookingPaymentState(bookingId)).status;

  /// État du paiement d'une réservation : `paid`, `failed` (avec le motif
  /// Mobile Money s'il est connu) ou `pending`.
  Future<({String status, String? failure})> bookingPaymentState(
    int bookingId,
  ) async {
    try {
      final response = await _dio.get('/v1/diaspo/bookings/$bookingId/payment-status');
      final data = response.data['data'] ?? {};
      final paymentStatus = data['payment_status']?.toString() ?? 'pending';
      final status = data['status']?.toString() ?? 'pending';
      final failure = data['payment_failure']?.toString();
      if (paymentStatus == 'completed') return (status: 'paid', failure: null);
      if (status == 'cancelled') return (status: 'failed', failure: failure);
      return (status: 'pending', failure: null);
    } catch (e) {
      return (status: 'pending', failure: null);
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
      throw Exception('data.diaspo.confirm_delivery_error'.tr);
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
      throw Exception('data.diaspo.confirm_delivery_code_error'.tr);
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

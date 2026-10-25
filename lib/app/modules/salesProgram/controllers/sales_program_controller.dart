import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/models/sales_program.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/sales_program_service.dart';
import '../../../routes/app_pages.dart';

typedef SalesProgramRequest = Future<ApiResponse> Function();

/// Modalités du programme commercial et inscription de l'utilisateur.
class SalesProgramController extends GetxController {
  SalesProgramController({
    SalesProgramRequest? fetchProgram,
    SalesProgramRequest? enrollRequest,
  })  : _fetchProgram = fetchProgram ?? SalesProgramService.getProgram,
        _enrollRequest = enrollRequest ?? SalesProgramService.enroll;

  final SalesProgramRequest _fetchProgram;
  final SalesProgramRequest _enrollRequest;

  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final program = Rx<SalesProgram?>(null);
  final termsAccepted = false.obs;
  final isEnrolling = false.obs;

  bool get canSubmit => termsAccepted.value && !isEnrolling.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await _fetchProgram();
      if (isClosed) return;
      final data = response.data?['data'];
      if (response.success && data is Map) {
        program.value = SalesProgram.fromJson(Map<String, dynamic>.from(data));
      } else {
        errorMessage.value = response.message.isNotEmpty
            ? response.message
            : 'sales_program.load_error'.tr;
      }
    } catch (_) {
      if (!isClosed) errorMessage.value = 'sales_program.load_error'.tr;
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  void toggleTermsAccepted() {
    termsAccepted.value = !termsAccepted.value;
  }

  Future<void> enroll() async {
    if (!canSubmit) return;
    isEnrolling.value = true;
    try {
      final response = await _enrollRequest();
      if (isClosed) return;
      final data = response.data?['data'];
      final code = data is Map ? data['code']?.toString() : null;
      if (response.success && code != null && code.isNotEmpty) {
        final rate = data is Map
            ? SalesProgram.parseRate(data['commission_rate'])
            : program.value?.commissionRate ?? 0;
        // Remplace les modalités : un retour arrière depuis les félicitations
        // ramène aux paramètres, pas à une case déjà cochée.
        Get.offNamed(
          Routes.SALES_PROGRAM_SUCCESS,
          arguments: {'code': code, 'commission_rate': rate},
        );
        return;
      }
      _showError(response.message.isNotEmpty && response.message != 'common.error'.tr
          ? response.message
          : 'sales_program.enroll_error'.tr);
    } catch (_) {
      if (!isClosed) _showError('sales_program.enroll_error'.tr);
    } finally {
      if (!isClosed) isEnrolling.value = false;
    }
  }

  void _showError(String message) {
    AppFeedback.show(
      'common.error'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.danger,
      colorText: Colors.white,
    );
  }
}

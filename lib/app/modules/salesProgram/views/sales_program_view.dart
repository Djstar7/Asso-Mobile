import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/sales_program.dart';
import '../controllers/sales_program_controller.dart';
import '../widgets/sales_agent_code_panel.dart';

/// Modalités du programme commercial, acceptées avant d'obtenir son code.
class SalesProgramView extends GetView<SalesProgramController> {
  const SalesProgramView({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Scaffold(
      backgroundColor: ds.canvas,
      appBar: AppBar(
        backgroundColor: ds.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: false,
        title: Text(
          'sales_program.app_bar'.tr,
          style: context.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final program = controller.program.value;
          if (controller.isLoading.value && program == null) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppDesign.accent),
                strokeWidth: 2.5,
              ),
            );
          }
          if (program == null) {
            return AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'sales_program.load_error_title'.tr,
              message: controller.errorMessage.value,
              actionLabel: 'common.retry'.tr,
              onAction: controller.load,
            );
          }
          if (program.isAgent && program.code != null) {
            return _buildAgentState(context, program);
          }
          return _buildTermsState(context, program);
        }),
      ),
    );
  }

  Widget _buildScrollable(BuildContext context, List<Widget> children) {
    final ds = context.ds;
    return SingleChildScrollView(
      child: AppContentWidth(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ds.gutter,
            AppDesign.space2,
            ds.gutter,
            AppDesign.space8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, String intro) {
    final ds = context.ds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textStyle(
            FontSizeType.h4,
            fontWeight: FontWeight.w700,
            color: ds.textPrimary,
          ),
        ),
        SizedBox(height: AppDesign.space2),
        Text(
          intro,
          style: context.textStyle(
            FontSizeType.body2,
            color: ds.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsState(BuildContext context, SalesProgram program) {
    final ds = context.ds;
    final terms = program.terms.trim();
    return Column(
      children: [
        Expanded(
          child: _buildScrollable(context, [
            _buildHeader(
              context,
              'sales_program.title'.tr,
              'sales_program.intro'.tr,
            ),
            SizedBox(height: AppDesign.space5),
            _buildCommissionCard(context, program.commissionRate),
            SizedBox(height: AppDesign.space6),
            Text(
              'sales_program.terms_title'.tr,
              style: context.textStyle(
                FontSizeType.subtitle1,
                fontWeight: FontWeight.w700,
                color: ds.textPrimary,
              ),
            ),
            SizedBox(height: AppDesign.space3),
            AppCard(
              padding: EdgeInsets.all(AppDesign.space4),
              child: Text(
                terms.isNotEmpty ? terms : 'sales_program.terms_empty'.tr,
                style: context.textStyle(
                  FontSizeType.body2,
                  color: terms.isNotEmpty ? ds.textPrimary : ds.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ]),
        ),
        _buildAcceptBar(context),
      ],
    );
  }

  Widget _buildCommissionCard(BuildContext context, double rate) {
    final ds = context.ds;
    return Container(
      padding: EdgeInsets.all(AppDesign.space4),
      decoration: BoxDecoration(
        color: AppDesign.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        border: Border.all(color: AppDesign.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.percent_rounded, size: 22, color: AppDesign.accent),
          SizedBox(width: AppDesign.space3),
          Expanded(
            child: Text(
              'sales_program.commission'.trParams({
                'rate': SalesProgram.formatRate(rate),
              }),
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.w600,
                color: ds.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptBar(BuildContext context) {
    final ds = context.ds;
    return Container(
      decoration: BoxDecoration(
        color: ds.surface,
        border: Border(top: BorderSide(color: ds.border)),
      ),
      child: AppContentWidth(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ds.gutter,
            AppDesign.space3,
            ds.gutter,
            AppDesign.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toute la ligne coche la case, comme à l'inscription.
              GestureDetector(
                key: const ValueKey('sales-program-accept'),
                behavior: HitTestBehavior.opaque,
                onTap: controller.toggleTermsAccepted,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDesign.minTapTarget,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Obx(
                          () => Checkbox(
                            value: controller.termsAccepted.value,
                            onChanged: (value) =>
                                controller.termsAccepted.value = value ?? false,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      SizedBox(width: AppDesign.space3),
                      Expanded(
                        child: Text(
                          'sales_program.accept'.tr,
                          style: context.textStyle(
                            FontSizeType.body2,
                            color: ds.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppDesign.space3),
              Obx(
                () => AppButton(
                  label: 'sales_program.submit'.tr,
                  isLoading: controller.isEnrolling.value,
                  onPressed: controller.termsAccepted.value
                      ? controller.enroll
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentState(BuildContext context, SalesProgram program) {
    return _buildScrollable(context, [
      _buildHeader(
        context,
        'sales_program.agent.title'.tr,
        'sales_program.agent.intro'.tr,
      ),
      if (!program.isActive) ...[
        SizedBox(height: AppDesign.space4),
        _buildInactiveNotice(context),
      ],
      SizedBox(height: AppDesign.space5),
      SalesAgentCodePanel(
        code: program.code!,
        commissionRate: program.commissionRate,
      ),
    ]);
  }

  Widget _buildInactiveNotice(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDesign.space4),
      decoration: BoxDecoration(
        color: AppDesign.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        border: Border.all(color: AppDesign.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, size: 20, color: AppDesign.warning),
          SizedBox(width: AppDesign.space3),
          Expanded(
            child: Text(
              'sales_program.agent.inactive'.tr,
              style: context.textStyle(
                FontSizeType.body2,
                fontWeight: FontWeight.w600,
                color: context.ds.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

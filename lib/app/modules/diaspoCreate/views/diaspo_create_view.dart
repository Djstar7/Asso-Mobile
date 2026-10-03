import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/diaspo_create_controller.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

class DiaspoCreateView extends GetView<DiaspoCreateController> {
  const DiaspoCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : Colors.grey[100],
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('diaspo_create.title'.tr),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Obx(() => _buildProgressIndicator(context, isDark)),

          // Step content
          Expanded(
            child: Obx(() {
              switch (controller.currentStep.value) {
                case 0:
                  return _buildStep1Itinerary(context, isDark);
                case 1:
                  return _buildStep2Pricing(context, isDark);
                case 2:
                  return _buildStep3Confirmation(context, isDark);
                default:
                  return const SizedBox();
              }
            }),
          ),

          // Navigation buttons
          Obx(() => _buildNavigationButtons(context, isDark)),
        ],
      ),
    );
  }

  /// Progress indicator
  Widget _buildProgressIndicator(BuildContext context, bool isDark) {
    final horizontalPadding = AppThemeSystem.getHorizontalPadding(context);
    final elementSpacing = AppThemeSystem.getElementSpacing(context);

    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
      child: Row(
        children: List.generate(controller.totalSteps, (index) {
          final isActive = index == controller.currentStep.value;
          final isCompleted = index < controller.currentStep.value;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? AppThemeSystem.primaryColor
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < controller.totalSteps - 1) SizedBox(width: elementSpacing * 0.5),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Step 1: Itinerary
  Widget _buildStep1Itinerary(BuildContext context, bool isDark) {
    final horizontalPadding = AppThemeSystem.getHorizontalPadding(context);
    final elementSpacing = AppThemeSystem.getElementSpacing(context);
    final sectionSpacing = AppThemeSystem.getSectionSpacing(context);
    final borderRadius = AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium);

    return SingleChildScrollView(
      // Le clavier cache la moitié de l'étape : un glissement pour relire
      // les champs le referme.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.all(horizontalPadding),
      child: Form(
        key: controller.formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'diaspo_create.step1_title'.tr,
              style: AppThemeSystem.getTextStyle(
                context,
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: elementSpacing * 0.5),
            Text(
              'diaspo_create.step1_subtitle'.tr,
              style: AppThemeSystem.getTextStyle(
                context,
                FontSizeType.body2,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
            ),
            SizedBox(height: sectionSpacing),

            // Departure
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: AppDesign.success),
                SizedBox(width: elementSpacing * 0.5),
                Text(
                  'diaspo_create.departure'.tr,
                  style: AppThemeSystem.getTextStyle(
                    context,
                    FontSizeType.subtitle1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: elementSpacing),
            Obx(() => TextFormField(
                  controller: controller.departureCountryController,
                  readOnly: true,
                  onTap: () => controller.pickCountry(isDeparture: true),
                  decoration: InputDecoration(
                    labelText: 'diaspo_create.departure_country'.tr,
                    hintText: 'diaspo_create.select_country_hint'.tr,
                    prefixIcon: const Icon(Icons.flag),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    helperText:
                        'diaspo_create.offer_currency'.trParams({
                      'code': controller.selectedCurrencyCode.value,
                      'symbol': controller.selectedCurrencySymbol.value,
                    }),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'diaspo_create.departure_country_required'.tr;
                    }
                    return null;
                  },
                )),
            SizedBox(height: elementSpacing),
            TextFormField(
              controller: controller.departureCityController,
              decoration: InputDecoration(
                labelText: 'diaspo_create.departure_city'.tr,
                hintText: 'diaspo_create.departure_city_hint'.tr,
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'diaspo_create.departure_city_required'.tr;
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            Obx(() => InkWell(
                  onTap: () => controller.pickDepartureDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'diaspo_create.departure_datetime'.tr,
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
                    ),
                    child: Text(
                      controller.formatDateTime(controller.departureDateTime.value),
                      style: TextStyle(
                        color: controller.departureDateTime.value == null
                            ? Colors.grey
                            : AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                  ),
                )),

            SizedBox(height: sectionSpacing * 1.3),

            // Arrival
            Row(
              children: [
                const Icon(Icons.flight_land, color: AppDesign.danger),
                SizedBox(width: elementSpacing * 0.5),
                Text(
                  'diaspo_create.arrival'.tr,
                  style: AppThemeSystem.getTextStyle(
                    context,
                    FontSizeType.subtitle1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: elementSpacing),
            TextFormField(
              controller: controller.arrivalCountryController,
              readOnly: true,
              onTap: () => controller.pickCountry(isDeparture: false),
              decoration: InputDecoration(
                labelText: 'diaspo_create.arrival_country'.tr,
                hintText: 'diaspo_create.select_country_hint'.tr,
                prefixIcon: const Icon(Icons.flag),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'diaspo_create.arrival_country_required'.tr;
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            TextFormField(
              controller: controller.arrivalCityController,
              decoration: InputDecoration(
                labelText: 'diaspo_create.arrival_city'.tr,
                hintText: 'diaspo_create.arrival_city_hint'.tr,
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'diaspo_create.arrival_city_required'.tr;
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            Obx(() => InkWell(
                  onTap: () {
                    if (controller.departureDateTime.value == null) {
                      Get.snackbar(
                        'diaspo_create.warning'.tr,
                        'diaspo_create.select_departure_first'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                      return;
                    }
                    controller.pickArrivalDate(context);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'diaspo_create.arrival_datetime'.tr,
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
                    ),
                    child: Text(
                      controller.formatDateTime(controller.arrivalDateTime.value),
                      style: TextStyle(
                        color: controller.arrivalDateTime.value == null
                            ? Colors.grey
                            : AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// Step 2: Pricing
  Widget _buildStep2Pricing(BuildContext context, bool isDark) {
    final horizontalPadding = AppThemeSystem.getHorizontalPadding(context);
    final elementSpacing = AppThemeSystem.getElementSpacing(context);
    final sectionSpacing = AppThemeSystem.getSectionSpacing(context);
    final borderRadius = AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium);

    return SingleChildScrollView(
      // Le clavier cache la moitié de l'étape : un glissement pour relire
      // les champs le referme.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.all(horizontalPadding),
      child: Form(
        key: controller.formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'diaspo_create.step2_title'.tr,
              style: AppThemeSystem.getTextStyle(
                context,
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: elementSpacing * 0.5),
            Text(
              'diaspo_create.step2_subtitle'.tr,
              style: AppThemeSystem.getTextStyle(
                context,
                FontSizeType.body2,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
            ),
            SizedBox(height: sectionSpacing),

            TextFormField(
              controller: controller.pricePerKgController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: InputDecoration(
                labelText: 'diaspo_create.price_per_kg_label'.trParams({'symbol': controller.offerCurrencySymbol}),
                hintText: 'diaspo_create.price_hint'.tr,
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: '${controller.offerCurrencySymbol}/kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              onChanged: (value) {
                controller.pricePerKg.value = double.tryParse(value) ?? 0.0;
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'diaspo_create.price_required'.tr;
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'diaspo_create.price_invalid'.tr;
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing * 1.3),
            TextFormField(
              controller: controller.availableKgController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: InputDecoration(
                labelText: 'diaspo_create.available_kg_label'.tr,
                hintText: 'diaspo_create.kg_hint'.tr,
                prefixIcon: const Icon(Icons.luggage),
                suffixText: 'kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              onChanged: (value) {
                controller.availableKg.value = double.tryParse(value) ?? 0.0;
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'diaspo_create.kg_required'.tr;
                }
                final kg = double.tryParse(value);
                if (kg == null || kg <= 0) {
                  return 'diaspo_create.kg_invalid'.tr;
                }
                return null;
              },
            ),
            SizedBox(height: sectionSpacing),

            // Potential total
            Container(
              padding: EdgeInsets.all(horizontalPadding),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'diaspo_create.potential_revenue'.tr,
                      style: AppThemeSystem.getTextStyle(
                        context,
                        FontSizeType.subtitle1,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: elementSpacing * 0.5),
                  Flexible(
                    child: Obx(() {
                      final total = controller.pricePerKg.value * controller.availableKg.value;
                      return Text(
                        '${total.toStringAsFixed(2)} ${controller.offerCurrencySymbol}',
                        style: AppThemeSystem.getTextStyle(
                          context,
                          FontSizeType.h4,
                          fontWeight: FontWeight.bold,
                          color: AppThemeSystem.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 3: Confirmation
  Widget _buildStep3Confirmation(BuildContext context, bool isDark) {
    final horizontalPadding = AppThemeSystem.getHorizontalPadding(context);
    final elementSpacing = AppThemeSystem.getElementSpacing(context);
    final sectionSpacing = AppThemeSystem.getSectionSpacing(context);
    final borderRadius = AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium);
    final iconSize = AppThemeSystem.getFontSize(context, FontSizeType.h5);

    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'diaspo_create.step3_title'.tr,
            style: AppThemeSystem.getTextStyle(
              context,
              FontSizeType.h4,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: elementSpacing * 0.5),
          Text(
            'diaspo_create.step3_subtitle'.tr,
            style: AppThemeSystem.getTextStyle(
              context,
              FontSizeType.body2,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
          ),
          SizedBox(height: sectionSpacing),

          // Summary card
          Card(
            elevation: AppThemeSystem.getElevation(context, ElevationType.low),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  Row(
                    children: [
                      Icon(Icons.flight_takeoff, color: AppDesign.success, size: iconSize),
                      SizedBox(width: elementSpacing * 0.5),
                      Expanded(
                        child: Text(
                          '${controller.departureCityController.text}, ${controller.departureCountryController.text}',
                          style: AppThemeSystem.getTextStyle(
                            context,
                            FontSizeType.body1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: elementSpacing * 0.5),
                  Row(
                    children: [
                      Icon(Icons.flight_land, color: AppDesign.danger, size: iconSize),
                      SizedBox(width: elementSpacing * 0.5),
                      Expanded(
                        child: Text(
                          '${controller.arrivalCityController.text}, ${controller.arrivalCountryController.text}',
                          style: AppThemeSystem.getTextStyle(
                            context,
                            FontSizeType.body1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: sectionSpacing),

                  // Dates
                  _buildSummaryRow(
                    context,
                    'diaspo_create.departure'.tr,
                    controller.formatDateTime(controller.departureDateTime.value),
                    Icons.calendar_today,
                  ),
                  SizedBox(height: elementSpacing * 0.5),
                  _buildSummaryRow(
                    context,
                    'diaspo_create.arrival'.tr,
                    controller.formatDateTime(controller.arrivalDateTime.value),
                    Icons.calendar_today,
                  ),
                  Divider(height: sectionSpacing),

                  // Pricing
                  _buildSummaryRow(
                    context,
                    'diaspo_create.price_per_kg'.tr,
                    '${controller.pricePerKgController.text} ${controller.offerCurrencySymbol}/kg',
                    Icons.euro,
                  ),
                  SizedBox(height: elementSpacing * 0.5),
                  _buildSummaryRow(
                    context,
                    'diaspo_create.available_kg'.tr,
                    '${controller.availableKgController.text} kg',
                    Icons.luggage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Summary row
  Widget _buildSummaryRow(BuildContext context, String label, String value, IconData icon) {
    final elementSpacing = AppThemeSystem.getElementSpacing(context);
    final iconSize = AppThemeSystem.getFontSize(context, FontSizeType.subtitle2);

    return Row(
      children: [
        Icon(icon, size: iconSize, color: AppThemeSystem.getSecondaryTextColor(context)),
        SizedBox(width: elementSpacing * 0.5),
        Text(
          '$label: ',
          style: AppThemeSystem.getTextStyle(
            context,
            FontSizeType.body2,
            color: AppThemeSystem.getSecondaryTextColor(context),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppThemeSystem.getTextStyle(
              context,
              FontSizeType.body2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Navigation buttons
  Widget _buildNavigationButtons(BuildContext context, bool isDark) {
    final horizontalPadding = AppThemeSystem.getHorizontalPadding(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final buttonHeight = AppThemeSystem.getButtonHeight(context);

    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: horizontalPadding * 0.75,
        bottom: bottomPadding > 0 ? bottomPadding + 8 : horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (controller.currentStep.value > 0)
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed: controller.previousStep,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
                      ),
                    ),
                  ),
                  child: Text(
                    'diaspo_create.previous'.tr,
                    style: AppThemeSystem.getTextStyle(
                      context,
                      FontSizeType.button,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (controller.currentStep.value > 0)
            SizedBox(width: AppThemeSystem.getElementSpacing(context)),

          // Next/Submit button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.currentStep.value < controller.totalSteps - 1) {
                    controller.nextStep();
                  } else {
                    controller.submitOffer();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppThemeSystem.getBorderRadius(context, BorderRadiusType.medium),
                    ),
                  ),
                ),
                child: controller.isSubmitting.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        controller.currentStep.value < controller.totalSteps - 1
                            ? 'diaspo_create.next'.tr
                            : 'diaspo_create.publish'.tr,
                        style: AppThemeSystem.getTextStyle(
                          context,
                          FontSizeType.button,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

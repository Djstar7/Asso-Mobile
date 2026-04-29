import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/diaspo_create_controller.dart';

class DiaspoCreateView extends GetView<DiaspoCreateController> {
  const DiaspoCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Créer une offre'),
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
      padding: EdgeInsets.all(horizontalPadding),
      child: Form(
        key: controller.formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Étape 1/3: Itinéraire',
              style: AppThemeSystem.getTextStyle(
                context,
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: elementSpacing * 0.5),
            Text(
              'Indiquez votre trajet de voyage',
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
                const Icon(Icons.flight_takeoff, color: Colors.green),
                SizedBox(width: elementSpacing * 0.5),
                Text(
                  'Départ',
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
              controller: controller.departureCountryController,
              decoration: InputDecoration(
                labelText: 'Pays de départ',
                hintText: 'Ex: France',
                prefixIcon: const Icon(Icons.flag),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir le pays de départ';
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            TextFormField(
              controller: controller.departureCityController,
              decoration: InputDecoration(
                labelText: 'Ville de départ',
                hintText: 'Ex: Paris',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir la ville de départ';
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            Obx(() => InkWell(
                  onTap: () => controller.pickDepartureDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date et heure de départ',
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
                const Icon(Icons.flight_land, color: Colors.red),
                SizedBox(width: elementSpacing * 0.5),
                Text(
                  'Arrivée',
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
              decoration: InputDecoration(
                labelText: 'Pays d\'arrivée',
                hintText: 'Ex: Cameroun',
                prefixIcon: const Icon(Icons.flag),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir le pays d\'arrivée';
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            TextFormField(
              controller: controller.arrivalCityController,
              decoration: InputDecoration(
                labelText: 'Ville d\'arrivée',
                hintText: 'Ex: Douala',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir la ville d\'arrivée';
                }
                return null;
              },
            ),
            SizedBox(height: elementSpacing),
            Obx(() => InkWell(
                  onTap: () {
                    if (controller.departureDateTime.value == null) {
                      Get.snackbar(
                        'Attention',
                        'Veuillez d\'abord sélectionner la date de départ',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                      return;
                    }
                    controller.pickArrivalDate(context);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date et heure d\'arrivée',
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
      padding: EdgeInsets.all(horizontalPadding),
      child: Form(
        key: controller.formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Étape 2/3: Tarification',
              style: AppThemeSystem.getTextStyle(
                context,
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: elementSpacing * 0.5),
            Text(
              'Définissez votre prix et la quantité disponible',
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
                labelText: 'Prix par kilo (€)',
                hintText: 'Ex: 13.00',
                prefixIcon: const Icon(Icons.euro),
                suffixText: 'EUR/kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              onChanged: (value) {
                controller.pricePerKg.value = double.tryParse(value) ?? 0.0;
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir le prix par kilo';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Veuillez saisir un prix valide';
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
                labelText: 'Nombre de kilos disponibles',
                hintText: 'Ex: 23',
                prefixIcon: const Icon(Icons.luggage),
                suffixText: 'kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              onChanged: (value) {
                controller.availableKg.value = double.tryParse(value) ?? 0.0;
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir le nombre de kilos';
                }
                final kg = double.tryParse(value);
                if (kg == null || kg <= 0) {
                  return 'Veuillez saisir une quantité valide';
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
                      'Revenus potentiels:',
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
                        '${total.toStringAsFixed(2)} EUR',
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
            'Étape 3/3: Confirmation',
            style: AppThemeSystem.getTextStyle(
              context,
              FontSizeType.h4,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: elementSpacing * 0.5),
          Text(
            'Vérifiez votre offre avant de publier',
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
                      Icon(Icons.flight_takeoff, color: Colors.green, size: iconSize),
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
                      Icon(Icons.flight_land, color: Colors.red, size: iconSize),
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
                    'Départ',
                    controller.formatDateTime(controller.departureDateTime.value),
                    Icons.calendar_today,
                  ),
                  SizedBox(height: elementSpacing * 0.5),
                  _buildSummaryRow(
                    context,
                    'Arrivée',
                    controller.formatDateTime(controller.arrivalDateTime.value),
                    Icons.calendar_today,
                  ),
                  Divider(height: sectionSpacing),

                  // Pricing
                  _buildSummaryRow(
                    context,
                    'Prix par kilo',
                    '${controller.pricePerKgController.text} EUR/kg',
                    Icons.euro,
                  ),
                  SizedBox(height: elementSpacing * 0.5),
                  _buildSummaryRow(
                    context,
                    'Kilos disponibles',
                    '${controller.availableKgController.text} kg',
                    Icons.luggage,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: sectionSpacing),

          // Warning
          Container(
            padding: EdgeInsets.all(elementSpacing),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: elementSpacing),
                Expanded(
                  child: Text(
                    'Votre offre sera vérifiée par notre équipe avant publication (24-48h)',
                    style: AppThemeSystem.getTextStyle(
                      context,
                      FontSizeType.body2,
                    ),
                  ),
                ),
              ],
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
                    'Précédent',
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
                            ? 'Suivant'
                            : 'Publier',
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

import 'dart:async';

import 'package:asso/app/core/utils/app_design.dart';
import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:asso/app/core/widgets/app_ui.dart';
import 'package:asso/app/core/widgets/product_card.dart';
import 'package:asso/app/data/models/diaspo_booking.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/modules/wallet/widgets/quick_confirm_code_dialog.dart';
import 'package:asso/app/modules/wallet/widgets/confirm_code_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/themed_app.dart';

class _PendingDelivery extends DiaspoService {
  int requests = 0;
  final response = Completer<DiaspoBooking>();

  @override
  Future<DiaspoBooking> confirmDeliveryByCode({
    required String confirmationCode,
  }) {
    requests++;
    return response.future;
  }
}

void main() {
  tearDown(Get.reset);

  test(
    'actions use vivid brand orange and informative text stays readable',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      for (final surface in [
        Colors.white,
        AppDesign.neutral50,
        AppDesign.neutral100,
        AppDesign.accentSubtle,
      ]) {
        expect(
          contrast(AppDesign.neutral600, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(AppDesign.accent, const Color(0xFFFC9141));
      expect(AppThemeSystem.primaryColor, AppDesign.accent);
      expect(
        AppThemeSystem.getLightTheme().colorScheme.primary,
        AppDesign.accent,
      );
      expect(
        AppThemeSystem.getDarkTheme().colorScheme.primary,
        AppDesign.accent,
      );
      expect(AppDesign.onAccent, Colors.white);
      for (final theme in [
        AppThemeSystem.getLightTheme(),
        AppThemeSystem.getDarkTheme(),
      ]) {
        expect(theme.colorScheme.onPrimary, Colors.white);
        expect(theme.colorScheme.onTertiary, Colors.white);
        expect(
          theme.elevatedButtonTheme.style!.foregroundColor!.resolve({}),
          Colors.white,
        );
        expect(
          theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
          Colors.white,
        );
        expect(theme.floatingActionButtonTheme.foregroundColor, Colors.white);
        expect(theme.snackBarTheme.contentTextStyle!.color, Colors.white);
        expect(theme.snackBarTheme.actionTextColor, Colors.white);
        expect(theme.progressIndicatorTheme.color, const Color(0xFFFC9141));
        expect(
          theme.inputDecorationTheme.floatingLabelStyle!.color,
          const Color(0xFFFC9141),
        );
        expect(
          theme.inputDecorationTheme.focusedBorder!.borderSide.color,
          const Color(0xFFFC9141),
        );
        expect(theme.textSelectionTheme.cursorColor, const Color(0xFFFC9141));
      }
      expect(
        contrast(AppDesign.accentText, AppDesign.accentSubtle),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets('modal actions and snackbars share the reference orange', (
    tester,
  ) async {
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: AlertDialog(
            title: const Text('Confirmer la livraison'),
            actions: [
              AppButton(label: 'Confirmer', expand: false, onPressed: () {}),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
    final buttonMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(buttonMaterial.color, const Color(0xFFFC9141));
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Confirmer'))
          .text
          .style!
          .color,
      Colors.white,
    );
    final context = tester.element(find.byType(AlertDialog));
    final theme = Theme.of(context);
    expect(
      theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
      AppDesign.accent,
    );
    expect(
      theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
      AppDesign.accent,
    );
    expect(theme.snackBarTheme.backgroundColor, AppDesign.accent);

    AppFeedback.show('ASSO', 'Colis récupéré');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final snackbar = tester.widget<GetSnackBar>(find.byType(GetSnackBar));
    expect(snackbar.backgroundColor, AppDesign.accent);
    expect((snackbar.titleText! as Text).style!.color, Colors.white);
    expect((snackbar.messageText! as Text).style!.color, Colors.white);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('text and card radii stay stable when window height changes', (
    tester,
  ) async {
    final values = <(double, double)>[];
    for (final height in [640.0, 900.0]) {
      await tester.pumpWidget(
        themedApp(
          Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(375, height)),
                child: Builder(
                  builder: (context) {
                    values.add((
                      AppThemeSystem.getFontSize(context, FontSizeType.body2),
                      AppThemeSystem.getBorderRadius(
                        context,
                        BorderRadiusType.medium,
                      ),
                    ));
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );
    }
    expect(values, everyElement((14.0, AppDesign.radiusMd)));
  });

  testWidgets('long primary action wraps at 320 with text at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const label = 'Confirmer la remise de la commande au transporteur';
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(label: label, onPressed: () {}),
            ),
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text(label)).height, greaterThan(48));
    expect(tester.widget<Text>(find.text(label)).maxLines, isNull);
  });

  testWidgets('loading preserves the height of a multiline action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late StateSetter update;
    var loading = false;
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: AppButton(
                  label: 'Confirmer la remise de la commande au transporteur',
                  onPressed: () {},
                  isLoading: loading,
                ),
              );
            },
          ),
        ),
        textScale: 2,
      ),
    );
    final before = tester.getSize(find.byType(AppButton));
    expect(before.height, lessThan(300));
    update(() => loading = true);
    await tester.pump();
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .valueColor!
          .value,
      Colors.white,
    );
    expect(tester.getSize(find.byType(AppButton)), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared footer keeps the page body visible', (tester) async {
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: const Text('Contenu de la page'),
          bottomNavigationBar: AppButton(label: 'Continuer', onPressed: () {}),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppButton)).height, lessThan(100));
    expect(find.text('Contenu de la page').hitTestable(), findsOneWidget);
  });

  testWidgets('disabled action exposes its button role and state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      themedApp(const Scaffold(body: AppButton(label: 'Valider'))),
    );
    expect(
      tester.getSemantics(find.byType(AppButton)),
      matchesSemantics(
        label: 'Valider',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('Form validator error remains visible in shared field', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: Form(
            key: form,
            child: AppTextField(
              label: 'Adresse',
              validator: (_) =>
                  'Une adresse est nécessaire pour livrer la commande.',
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    final error = find.text(
      'Une adresse est nécessaire pour livrer la commande.',
    );
    expect(error, findsOneWidget);
    expect(tester.getSize(error).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('product grid reserves room for enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: Builder(
            builder: (context) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: ProductCard.gridDelegate(context),
                itemCount: 2,
                itemBuilder: (_, index) => const ProductCard(
                  name: 'Ensemble de cuisine avec accessoires de préparation',
                  price: '125 000 FCFA',
                  location: 'Douala, Cameroun',
                ),
              );
            },
          ),
        ),
        textScale: 2,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful confirmation returns to the original page', (
    tester,
  ) async {
    final service =
        Get.put<DiaspoService>(_PendingDelivery()) as _PendingDelivery;
    var refreshes = 0;
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: TextButton(
            onPressed: () => Get.dialog(
              QuickConfirmCodeDialog(onSuccess: () => refreshes++),
              barrierDismissible: false,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    service.response.complete(
      DiaspoBooking(
        id: 1,
        diaspoOfferId: 1,
        buyerUserId: 2,
        sellerUserId: 3,
        kgBooked: 1,
        pricePerKg: 1000,
        subtotal: 1000,
        commissionAmount: 0,
        totalPrice: 1000,
        status: 'completed',
        confirmationCode: 'ABC123',
        paymentStatus: 'paid',
        formattedTotal: '1 000 FCFA',
        isCompleted: true,
        createdAt: DateTime(2026, 10, 25),
        updatedAt: DateTime(2026, 10, 25),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuickConfirmCodeDialog), findsNothing);
    expect(find.byType(ConfirmCodeSuccessDialog), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ConfirmCodeSuccessDialog), findsNothing);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'code confirmation sends once and preserves the route while pending',
    (tester) async {
      final service =
          Get.put<DiaspoService>(_PendingDelivery()) as _PendingDelivery;
      await tester.pumpWidget(
        themedApp(
          Scaffold(
            body: TextButton(
              onPressed: () => Get.dialog(
                QuickConfirmCodeDialog(onSuccess: () {}),
                barrierDismissible: false,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Simulates the already queued keyboard callback after the first submit.
      final field = tester.widget<TextField>(find.byType(TextField));
      field.onSubmitted!('ABC123');
      await tester.pump();
      expect(service.requests, 1);
      expect(field.enabled, isFalse);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Annuler'))
            .onPressed,
        isNull,
      );
      Get.key.currentState!.maybePop();
      await tester.pump();
      expect(find.byType(QuickConfirmCodeDialog), findsOneWidget);

      service.response.completeError(Exception('Réseau indisponible'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      // The error is visible beside the code and Cancel closes the route.
      expect(find.text('Réseau indisponible'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickConfirmCodeDialog), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
}

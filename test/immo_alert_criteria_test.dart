import 'package:asso/app/data/models/real_estate_models.dart';
import 'package:asso/app/modules/immo/controllers/immo_home_controller.dart';
import 'package:asso/app/modules/immo/widgets/immo_sheets.dart';
import 'package:asso/app/modules/immo/immo_nav.dart';
import 'package:asso/app/modules/immo/views/immo_home_view.dart';
import 'package:asso/app/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);
  test(
    'terrain : le type reste présent lors du chargement puis de l’envoi',
    () {
      final criteria = RealEstateCriteria.fromJson({
        'type': 'land',
        'city': 'Yaoundé',
        'budget_max': 60000000,
      });
      expect(criteria.type, RealEstateType.land);
      expect(criteria.toJson(), {
        'type': 'land',
        'city': 'Yaoundé',
        'budget_max': 60000000,
      });
      expect(criteria.toJson().containsKey('lease_months'), isFalse);
      expect(criteria.toJson().containsKey('move_in_date'), isFalse);
    },
  );

  test(
    'les anciennes alertes sans type restent des recherches de location',
    () {
      final criteria = RealEstateCriteria.fromJson({'city': 'Douala'});
      expect(criteria.type, RealEstateType.rent);
      expect(criteria.toJson()['type'], 'rent');
    },
  );

  test('une notification terrain peut initialiser le bon onglet', () {
    final controller = ImmoHomeController(initialType: RealEstateType.land);
    expect(controller.type.value, RealEstateType.land);
    final route =
        ImmoNav.onGenerateRoute(
              const RouteSettings(name: ImmoNav.home, arguments: 'land'),
            )
            as GetPageRoute;
    expect((route.page!() as ImmoHomeView).initialType, RealEstateType.land);
  });

  for (final type in RealEstateType.values) {
    testWidgets(
      'critères $type : les conditions de location restent propres aux locations',
      (tester) async {
        final controller = ImmoHomeController(initialType: type);
        controller.criteria.value = RealEstateCriteria(
          type: type,
          city: 'Yaoundé',
        );
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: TextButton(
                onPressed: () => showImmoCriteriaSheet(controller),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        final submit = tester.widget<AppButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppButton &&
                widget.label == 'immo.criteria.submit'.tr,
          ),
        );
        if (type == RealEstateType.land) {
          expect(submit.onPressed, isNotNull);
          expect(find.byType(ImmoMonthsStepper), findsNothing);
          expect(
            tester.widget<ImmoRangeField>(find.byType(ImmoRangeField)).max,
            200000000,
          );
        } else {
          expect(submit.onPressed, isNull);
          expect(find.byType(ImmoMonthsStepper), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

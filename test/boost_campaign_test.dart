import 'package:asso/app/data/models/boost_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asso Ads — lecture des campagnes renvoyées par l'API.
///
/// Ce que le vendeur lit dans l'application vient directement de ces champs :
/// une erreur de parsing lui afficherait une portée fausse sur un achat réel.
void main() {
  group('BoostCampaign', () {
    Map<String, dynamic> payload({
      int quota = 1000,
      int served = 250,
      bool running = true,
    }) {
      return {
        'id': 7,
        'product': {'id': 42, 'name': 'Sac en cuir', 'image': null},
        'package_name': 'Coup de pouce',
        'status': running ? 'active' : 'completed',
        'status_label': running ? 'En diffusion' : 'Terminée (audience atteinte)',
        'is_running': running,
        'amount_xaf': 1000,
        'starts_at': '2026-09-20T10:00:00+00:00',
        'ends_at': '2026-09-22T10:00:00+00:00',
        'remaining_days': 2,
        'impressions_quota': quota,
        'impressions_served': served,
        'impressions_remaining': quota - served,
        'progress_percent': served / quota * 100,
        'reached': served,
        'viewers': 30,
        'interactions': 4,
        'clicks': 60,
        'click_through_rate': 24.0,
        'view_rate': 12.0,
        'series': [
          {'date': '2026-09-20', 'impressions': 150, 'clicks': 40},
          {'date': '2026-09-21', 'impressions': 100, 'clicks': 20},
        ],
      };
    }

    test('lit la portée achetée, délivrée et restante', () {
      final campaign = BoostCampaign.fromJson(payload());

      expect(campaign.id, 7);
      expect(campaign.productId, 42);
      expect(campaign.productName, 'Sac en cuir');
      expect(campaign.impressionsQuota, 1000);
      expect(campaign.impressionsServed, 250);
      expect(campaign.impressionsRemaining, 750);
      expect(campaign.isRunning, isTrue);
      expect(campaign.series, hasLength(2));
    });

    test('distingue les personnes touchées de celles qui ont interagi', () {
      final campaign = BoostCampaign.fromJson(payload());

      // Ces trois chiffres alimentent l'entonnoir de l'écran de suivi ; les
      // confondre donnerait au vendeur une idée fausse de son retour.
      expect(campaign.reached, 250);
      expect(campaign.clicks, 60);
      expect(campaign.viewers, 30);
      expect(campaign.interactions, 4);
    });

    test('borne la progression à 1 même si le quota est dépassé', () {
      final campaign = BoostCampaign.fromJson(
        payload(quota: 100, served: 120)..['progress_percent'] = 120,
      );

      // La barre de progression ne doit jamais déborder visuellement.
      expect(campaign.progressFraction, 1.0);
    });

    test('survit à une réponse incomplète sans planter', () {
      final campaign = BoostCampaign.fromJson({'id': 3});

      expect(campaign.id, 3);
      expect(campaign.productName, 'Article');
      expect(campaign.impressionsQuota, 0);
      expect(campaign.progressFraction, 0.0);
      expect(campaign.series, isEmpty);
      expect(campaign.startsAt, isNull);
    });

    test('accepte les nombres transmis en chaîne', () {
      final campaign = BoostCampaign.fromJson({
        'id': '9',
        'impressions_quota': '500',
        'impressions_served': '125',
        'progress_percent': '25.0',
      });

      expect(campaign.id, 9);
      expect(campaign.impressionsQuota, 500);
      expect(campaign.impressionsServed, 125);
      expect(campaign.progressFraction, 0.25);
    });
  });

  group('BoostPackage', () {
    test('lit le quota de vues et le prix', () {
      final package = BoostPackage.fromJson({
        'id': 4,
        'name': 'Coup de pouce',
        'price': 1000,
        'formatted_price': '1 000 FCFA',
        'duration_days': 2,
        'formatted_duration': '2 jours',
        'reach_users': 1000,
        'formatted_reach': '1 000 personnes',
        'is_popular': false,
      });

      expect(package.reachUsers, 1000);
      expect(package.durationDays, 2);
      expect(package.pricePerPerson, 1.0);
    });

    test('ne divise pas par zéro sur un forfait mal configuré', () {
      final package = BoostPackage.fromJson({
        'id': 5,
        'name': 'Cassé',
        'price': 1000,
        'reach_users': 0,
      });

      expect(package.pricePerPerson, 0);
    });
  });
}

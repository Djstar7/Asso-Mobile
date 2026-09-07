import 'package:flutter_test/flutter_test.dart';
import 'package:asso/app/modules/product/controllers/product_controller.dart';

void main() {
  group('ProductController', () {
    test('initializes delivery form fields with default empty values', () {
      final controller = ProductController();

      expect(controller.currentLocation.value, isEmpty);
      expect(controller.orderQuantity.value, 1);
      expect(controller.withDelivery.value, isFalse);
      expect(controller.addressDetailsController.text, isEmpty);
      expect(controller.customerPhoneController.text, isEmpty);
    });
  });
}

import 'package:asso/app/modules/addProduct/controllers/add_product_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  tearDown(Get.reset);

  AddProductController controller({bool editing = true}) {
    final value = AddProductController();
    value.isEditMode.value = editing;
    value.nameController.text = 'Téléphone';
    addTearDown(value.onClose);
    return value;
  }

  Future<void> expectValidation(
    WidgetTester tester,
    AddProductController value,
    String message,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await value.submitProduct();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final snackbar = tester.widget<GetSnackBar>(find.byType(GetSnackBar));
    final actual = (snackbar.messageText! as Text).data;
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
    expect(actual, message.tr);
  }

  testWidgets('une modification sans nouvelle photo conserve les existantes', (
    tester,
  ) async {
    final value = controller();
    value.existingImages.add({
      'id': 42,
      'url': 'https://example.com/photo.jpg',
      'isPrimary': true,
    });
    value.newImageStartIndex.value = 1;

    expect(value.imagesForUpload, isEmpty);
    // La validation atteint le champ suivant, sans réclamer une nouvelle photo.
    await expectValidation(
      tester,
      value,
      'add_product.validation.category_required',
    );
  });

  test(
    'toutes les nouvelles photos sont envoyées avec des photos existantes',
    () {
      final value = controller();
      value.existingImages.addAll([
        {'id': 41, 'url': 'https://example.com/1.jpg'},
        {'id': 42, 'url': 'https://example.com/2.jpg'},
      ]);
      value.existingImageIds.addAll([41, 42]);
      value.newImageStartIndex.value = 2;
      final first = XFile('nouvelle-1.jpg');
      final second = XFile('nouvelle-2.jpg');
      value.productImages.addAll([first, second]);
      expect(value.imagesForUpload, [first, second]);

      value.removeImage(0);
      expect(value.deletedImageIds, [41]);
      expect(value.existingImageIds, [42]);
      expect(value.imagesForUpload, [first, second]);
    },
  );

  testWidgets('supprimer la dernière photo exige une photo de remplacement', (
    tester,
  ) async {
    final value = controller();
    value.existingImages.add({
      'id': 42,
      'url': 'https://example.com/photo.jpg',
    });
    value.existingImageIds.add(42);
    value.removeImage(0);
    expect(value.deletedImageIds, [42]);
    await expectValidation(
      tester,
      value,
      'add_product.validation.image_required',
    );
  });

  testWidgets('une création sans photo reste refusée', (tester) async {
    await expectValidation(
      tester,
      controller(editing: false),
      'add_product.validation.image_required',
    );
  });

  test('une création envoie toujours la photo principale en premier', () {
    final value = controller(editing: false);
    final first = XFile('photo-1.jpg');
    final second = XFile('photo-2.jpg');
    value.productImages.addAll([first, second]);
    value.setPrimaryImage(1);
    expect(value.imagesForUpload, [second, first]);
  });
}

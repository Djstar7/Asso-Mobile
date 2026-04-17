import 'package:get/get.dart';
import '../../../data/providers/shop_service.dart';

class VendorDetailsController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<Map<String, dynamic>> shopData = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> shopStats = Rxn<Map<String, dynamic>>();

  String? shopId;

  @override
  void onInit() {
    super.onInit();

    // Get shop ID from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    shopId = args?['shop_id']?.toString();

    if (shopId != null) {
      fetchShopDetails();
    } else {
      hasError.value = true;
      errorMessage.value = 'ID de boutique invalide';
      isLoading.value = false;
    }
  }

  Future<void> fetchShopDetails() async {
    if (shopId == null) return;

    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';

      print('🏪 Fetching shop details for ID: $shopId');

      final response = await ShopService.getPublicShop(shopId!);

      if (response.success && response.data != null) {
        shopData.value = response.data!['shop'] as Map<String, dynamic>?;
        shopStats.value = response.data!['stats'] as Map<String, dynamic>?;

        // Extract products from shop data
        final shopProducts = shopData.value?['products'] as List<dynamic>?;
        if (shopProducts != null) {
          products.value = shopProducts.cast<Map<String, dynamic>>();
        }

        print('✅ Shop details loaded successfully');
        print('   Shop name: ${shopData.value?['name']}');
        print('   Products count: ${products.length}');
      } else {
        hasError.value = true;
        errorMessage.value = response.message.isNotEmpty
            ? response.message
            : 'Impossible de charger les détails de la boutique';
      }
    } catch (e) {
      print('❌ Error fetching shop details: $e');
      hasError.value = true;
      errorMessage.value = 'Une erreur est survenue lors du chargement';
    } finally {
      isLoading.value = false;
    }
  }

  void onProductTap(Map<String, dynamic> product) {
    // Navigate to product details
    Get.toNamed('/product', arguments: product);
  }

  Future<void> refreshShopDetails() async {
    await fetchShopDetails();
  }
}

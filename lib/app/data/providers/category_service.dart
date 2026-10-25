import '../../core/values/constants.dart';
import '../models/category_model.dart';
import 'api_provider.dart';

class CategoryService {
  /// Get all categories
  static Future<List<CategoryModel>> getCategories() async {
    print('');
    print('========================================');
    print('📂 CATEGORY SERVICE: Fetch Categories START');
    print('========================================');

    try {
      print('🌐 CATEGORY SERVICE: Calling API...');
      print('  └─ Endpoint: ${AppConstants.categoriesUrl}');

      final response = await ApiProvider.get(AppConstants.categoriesUrl);

      print('📥 CATEGORY SERVICE: API Response received');
      print('  └─ Success: ${response.success}');
      print('  └─ Status Code: ${response.statusCode}');

      if (response.success && response.data != null) {
        final categoriesJson = response.data!['categories'] as List?;

        if (categoriesJson != null) {
          final categories = categoriesJson
              .map((json) => CategoryModel.fromJson(json as Map<String, dynamic>))
              .toList();

          print('✅ CATEGORY SERVICE: Categories loaded');
          print('  └─ Total categories: ${categories.length}');
          print('========================================');

          return categories;
        } else {
          print('⚠️ CATEGORY SERVICE: No categories in response');
          print('========================================');
          return [];
        }
      } else {
        print('❌ CATEGORY SERVICE: API failed');
        print('========================================');
        return [];
      }
    } catch (e, stackTrace) {
      print('💥 CATEGORY SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      return [];
    }
  }
}

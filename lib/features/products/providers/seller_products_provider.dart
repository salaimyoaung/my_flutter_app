import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

final sellerProductsProvider =
FutureProvider.family<List<Product>, String>((ref, sellerId) async {

  final repo = ref.watch(productRepositoryProvider);

  return repo.getSellerProducts(sellerId);

});
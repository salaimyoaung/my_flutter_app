import '../models/product_model.dart';
import '../services/product_service.dart';

class ProductRepository {

  final ProductService _service;

  ProductRepository({ProductService? service})
      : _service = service ?? ProductService();

  Future<List<Product>> getSellerProducts(String sellerId) {
    return _service.getProductsBySeller(sellerId);
  }
}
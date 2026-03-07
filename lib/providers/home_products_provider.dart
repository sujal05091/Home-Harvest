import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/home_product_model.dart';

class HomeProductsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _allProductsSub;
  StreamSubscription<QuerySnapshot>? _sellerProductsSub;

  List<HomeProductModel> _allProducts = [];
  List<HomeProductModel> _sellerProducts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<HomeProductModel> get allProducts => _allProducts;
  List<HomeProductModel> get sellerProducts => _sellerProducts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// All unique sellers derived from products
  List<HomeSellerSummary> get sellers {
    final Map<String, List<HomeProductModel>> grouped = {};
    for (final p in _allProducts) {
      grouped.putIfAbsent(p.sellerId, () => []).add(p);
    }
    return grouped.entries.map((e) {
      final products = e.value;
      final totalRating = products.fold<double>(
          0, (sum, p) => sum + (p.rating * p.totalRatings));
      final totalRatingCount =
          products.fold<int>(0, (sum, p) => sum + p.totalRatings);
      final avgRating =
          totalRatingCount > 0 ? totalRating / totalRatingCount : 0.0;
      return HomeSellerSummary(
        sellerId: e.key,
        sellerName: products.first.sellerName,
        verifiedSeller: products.first.verifiedSeller,
        avgRating: avgRating,
        productCount: products.length,
      );
    }).toList()
      ..sort((a, b) => b.avgRating.compareTo(a.avgRating));
  }

  /// Start real-time listener for all available products (customer market view).
  /// Cancels any previous subscription first so it's safe to call multiple times.
  void loadAllProducts() {
    _allProductsSub?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _allProductsSub = _firestore
        .collection('home_products')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen(
          (snap) {
            _allProducts = snap.docs
                .map((d) => HomeProductModel.fromMap(
                    d.data() as Map<String, dynamic>, d.id))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Cancel the all-products real-time listener (call when market screen
  /// is permanently disposed to avoid unnecessary Firestore reads).
  void cancelAllProductsListener() {
    _allProductsSub?.cancel();
    _allProductsSub = null;
  }

  /// Real-time listener for a seller's own products (Manage Products tab).
  void loadSellerProducts(String sellerId) {
    _sellerProductsSub?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _sellerProductsSub = _firestore
        .collection('home_products')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            _sellerProducts = snap.docs
                .map((d) => HomeProductModel.fromMap(
                    d.data() as Map<String, dynamic>, d.id))
                .toList();
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Cancel the seller-products real-time listener.
  void cancelSellerProductsListener() {
    _sellerProductsSub?.cancel();
    _sellerProductsSub = null;
  }

  /// Products for a given seller from the already-loaded all-products list
  List<HomeProductModel> productsForSeller(String sellerId) =>
      _allProducts.where((p) => p.sellerId == sellerId).toList();

  /// Add a new product (real-time stream auto-updates sellerProducts list)
  Future<bool> addProduct(HomeProductModel product) async {
    try {
      await _firestore
          .collection('home_products')
          .add(product.toMap());
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an existing product
  Future<bool> updateProduct(HomeProductModel product) async {
    try {
      await _firestore
          .collection('home_products')
          .doc(product.productId)
          .update(product.toMap());
      // Update local cache
      final idx =
          _sellerProducts.indexWhere((p) => p.productId == product.productId);
      if (idx != -1) {
        _sellerProducts[idx] = product;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a product
  Future<bool> deleteProduct(String productId, String sellerId) async {
    try {
      await _firestore.collection('home_products').doc(productId).delete();
      _sellerProducts.removeWhere((p) => p.productId == productId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle availability
  Future<void> toggleAvailability(HomeProductModel product) async {
    final updated = product.copyWith(isAvailable: !product.isAvailable);
    await updateProduct(updated);
  }

  @override
  void dispose() {
    _allProductsSub?.cancel();
    _sellerProductsSub?.cancel();
    super.dispose();
  }
}

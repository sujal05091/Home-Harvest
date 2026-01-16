import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/dish_model.dart';
import '../services/firestore_service.dart';

class DishesProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<DishModel> _dishes = [];
  List<DishModel> _filteredDishes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DishModel> get dishes => _filteredDishes.isEmpty ? _dishes : _filteredDishes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load all dishes
  void loadDishes() {
    _isLoading = true;
    notifyListeners();

    _firestoreService.getDishes().listen(
      (dishes) {
        _dishes = dishes;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Load cook's dishes
  void loadCookDishes(String cookId) {
    _isLoading = true;
    notifyListeners();

    _firestoreService.getCookDishes(cookId).listen(
      (dishes) {
        _dishes = dishes;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Filter dishes by search query
  void searchDishes(String query) {
    if (query.isEmpty) {
      _filteredDishes = [];
    } else {
      _filteredDishes = _dishes
          .where((dish) =>
              dish.title.toLowerCase().contains(query.toLowerCase()) ||
              dish.description.toLowerCase().contains(query.toLowerCase()) ||
              dish.cookName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  // Filter dishes by location radius using Geoflutterfire
  void filterByLocation(double userLat, double userLng, double radiusKm) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Use basic distance calculation for now
      // For production, implement geoflutterfire_plus queries directly in Firestore
      _filteredDishes = _dishes.where((dish) {
        double distance = _calculateDistance(
          userLat,
          userLng,
          dish.location.latitude,
          dish.location.longitude,
        );
        return distance <= radiusKm;
      }).toList();
      
      // Sort by distance
      _filteredDishes.sort((a, b) {
        double distA = _calculateDistance(userLat, userLng, a.location.latitude, a.location.longitude);
        double distB = _calculateDistance(userLat, userLng, b.location.latitude, b.location.longitude);
        return distA.compareTo(distB);
      });
      
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  // Get dish by ID
  Future<DishModel?> getDishById(String dishId) async {
    try {
      return await _firestoreService.getDishById(dishId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Add dish
  Future<bool> addDish(DishModel dish) async {
    try {
      await _firestoreService.addDish(dish);
      // Add to local list immediately
      _dishes.add(dish);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update dish
  Future<bool> updateDish(DishModel dish) async {
    try {
      await _firestoreService.updateDish(dish);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete dish
  Future<bool> deleteDish(String dishId) async {
    try {
      await _firestoreService.deleteDish(dishId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Provider for managing user favorites (cooks and dishes)
class FavoritesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<String> _favoriteCooks = [];
  List<String> _favoriteDishes = [];
  bool _isLoading = false;
  String? _userId;

  List<String> get favoriteCooks => _favoriteCooks;
  List<String> get favoriteDishes => _favoriteDishes;
  bool get isLoading => _isLoading;

  /// Load user's favorites from Firestore
  Future<void> loadFavorites(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('favorites').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _favoriteCooks = List<String>.from(data['cooks'] ?? []);
        _favoriteDishes = List<String>.from(data['dishes'] ?? []);
      }
    } catch (e) {
      print('Error loading favorites: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle cook as favorite
  Future<void> toggleCookFavorite(String cookId) async {
    if (_userId == null) return;

    final isFavorite = _favoriteCooks.contains(cookId);
    
    if (isFavorite) {
      _favoriteCooks.remove(cookId);
    } else {
      _favoriteCooks.add(cookId);
    }
    notifyListeners();

    try {
      await _firestore.collection('favorites').doc(_userId).set({
        'cooks': _favoriteCooks,
        'dishes': _favoriteDishes,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Revert on error
      if (isFavorite) {
        _favoriteCooks.add(cookId);
      } else {
        _favoriteCooks.remove(cookId);
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle dish as favorite
  Future<void> toggleDishFavorite(String dishId) async {
    if (_userId == null) return;

    final isFavorite = _favoriteDishes.contains(dishId);
    
    if (isFavorite) {
      _favoriteDishes.remove(dishId);
    } else {
      _favoriteDishes.add(dishId);
    }
    notifyListeners();

    try {
      await _firestore.collection('favorites').doc(_userId).set({
        'cooks': _favoriteCooks,
        'dishes': _favoriteDishes,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Revert on error
      if (isFavorite) {
        _favoriteDishes.add(dishId);
      } else {
        _favoriteDishes.remove(dishId);
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Check if cook is favorite
  bool isCookFavorite(String cookId) => _favoriteCooks.contains(cookId);

  /// Check if dish is favorite
  bool isDishFavorite(String dishId) => _favoriteDishes.contains(dishId);

  /// Clear all favorites
  Future<void> clearAllFavorites() async {
    if (_userId == null) return;

    _favoriteCooks.clear();
    _favoriteDishes.clear();
    notifyListeners();

    try {
      await _firestore.collection('favorites').doc(_userId).delete();
    } catch (e) {
      print('Error clearing favorites: $e');
      rethrow;
    }
  }
}

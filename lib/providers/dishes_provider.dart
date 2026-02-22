import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/dish_model.dart';
import '../models/cook_section_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DishesProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<DishModel> _dishes = [];
  List<DishModel> _filteredDishes = [];
  List<CookSectionModel> _cookSections = [];
  bool _isLoading = false;
  bool _isCookSectionsLoading = false;
  String? _errorMessage;

  List<DishModel> get dishes => _filteredDishes.isEmpty ? _dishes : _filteredDishes;
  List<CookSectionModel> get cookSections => _cookSections;
  bool get isLoading => _isLoading;
  bool get isCookSectionsLoading => _isCookSectionsLoading;
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
      
      // Update in local list for immediate UI feedback
      final index = _dishes.indexWhere((d) => d.dishId == dish.dishId);
      if (index != -1) {
        _dishes[index] = dish;
        notifyListeners();
      }
      
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
      
      // Remove from local list for immediate UI feedback
      _dishes.removeWhere((dish) => dish.dishId == dishId);
      _filteredDishes.removeWhere((dish) => dish.dishId == dishId);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load dishes grouped by cook (for Swiggy/Zomato-style grouped UI)
  /// Fetches all verified cooks and their available dishes
  Future<void> loadCooksWithDishes() async {
    print('🔍 [DishesProvider] Starting loadCooksWithDishes...');
    _isCookSectionsLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Step 1: Fetch all verified cooks
      print('📥 [Step 1] Fetching verified cooks...');
      final cooksSnapshot = await firestore
          .collection('users')
          .where('role', isEqualTo: 'cook')
          .where('verified', isEqualTo: true)
          .get();

      print('✅ Found ${cooksSnapshot.docs.length} verified cooks');

      List<CookSectionModel> cookSections = [];

      // Step 2: For each cook, fetch their available dishes
      for (var cookDoc in cooksSnapshot.docs) {
        final cookData = cookDoc.data();
        final cookId = cookDoc.id;
        final cookName = cookData['name'] ?? 'Unknown Cook';

        print('👨‍🍳 Processing cook: $cookName (ID: $cookId)');

        // Fetch dishes for this cook
        final dishesSnapshot = await firestore
            .collection('dishes')
            .where('cookId', isEqualTo: cookId)
            .get();  // Removed isAvailable filter temporarily to see all dishes

        print('   📊 Found ${dishesSnapshot.docs.length} total dishes for $cookName');

        // Convert to DishModel list (filter available ones in code)
        List<DishModel> dishes = dishesSnapshot.docs
            .map((doc) {
              final dish = DishModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              print('      🍽️ Dish: ${dish.title} (₹${dish.price}) - Available: ${dish.isAvailable}');
              return dish;
            })
            .where((dish) => dish.isAvailable)  // Filter in code
            .toList();

        // Only include cooks who have at least 1 available dish
        if (dishes.isNotEmpty) {
          // Calculate average rating
          double avgRating = CookSectionModel.calculateAverageRating(dishes);

          // Create cook section
          final cookSection = CookSectionModel(
            cookId: cookId,
            cookName: cookData['name'] ?? 'Unknown Cook',
            cookPhotoUrl: cookData['photoUrl'],
            cookAddress: cookData['address'],
            cookLocation: cookData['location'] as GeoPoint?,
            isVerified: cookData['verified'] ?? false,
            rating: double.parse(avgRating.toStringAsFixed(1)),
            totalDishes: dishes.length,
            dishes: dishes,
          );

          cookSections.add(cookSection);
          print('   ✅ Added cook section: $cookName with ${dishes.length} dishes, avg rating: $avgRating');
        } else {
          print('   ⚠️ Skipped $cookName - no available dishes');
        }
      }

      // Sort cook sections by rating (highest first)
      cookSections.sort((a, b) => b.rating.compareTo(a.rating));

      _cookSections = cookSections;
      _isCookSectionsLoading = false;
      notifyListeners();
      
      print('🎉 [COMPLETE] Loaded ${cookSections.length} cook sections');
      
    } catch (e) {
      _errorMessage = 'Failed to load cooks: ${e.toString()}';
      _isCookSectionsLoading = false;
      notifyListeners();
      print('❌ Error loading cooks with dishes: $e');
    }
  }

  /// Filter cook sections by search query, categories, and price
  /// Searches in cook name, dish title, and dish description
  List<CookSectionModel> filterCookSections(
    String query, {
    List<String>? categories,
    double? maxPrice,
    String? sortBy,
  }) {
    var filteredSections = _cookSections;

    // Filter by search query
    if (query.isNotEmpty) {
      filteredSections = filteredSections.where((section) {
        // Search in cook name
        if (section.cookName.toLowerCase().contains(query.toLowerCase())) {
          return true;
        }

        // Search in dish titles and descriptions
        return section.dishes.any((dish) =>
            dish.title.toLowerCase().contains(query.toLowerCase()) ||
            dish.description.toLowerCase().contains(query.toLowerCase()));
      }).toList();
    }

    // Filter by categories
    if (categories != null && categories.isNotEmpty) {
      filteredSections = filteredSections.map((section) {
        final filteredDishes = section.dishes.where((dish) {
          // Check if dish matches any selected category
          return categories.any((category) {
            final lowerCategory = category.toLowerCase();
            
            // Priority 1: Check categories field first (if exists and not null)
            final dishCategories = dish.categories ?? [];
            if (dishCategories.isNotEmpty) {
              final lowerDishCategories = dishCategories.map((c) => c.toLowerCase());
              if (lowerDishCategories.contains(lowerCategory)) {
                return true;
              }
            }
            
            // Priority 2: Fall back to text matching for backward compatibility
            final lowerTitle = dish.title.toLowerCase();
            final lowerDesc = dish.description.toLowerCase();
            final lowerIngredients = dish.ingredients.map((i) => i.toLowerCase()).join(' ');
            
            // Match category with dish properties
            return lowerTitle.contains(lowerCategory) ||
                   lowerDesc.contains(lowerCategory) ||
                   lowerIngredients.contains(lowerCategory);
          });
        }).toList();

        // Only include sections that have matching dishes
        if (filteredDishes.isEmpty) return null;

        return CookSectionModel(
          cookId: section.cookId,
          cookName: section.cookName,
          cookPhotoUrl: section.cookPhotoUrl,
          cookAddress: section.cookAddress,
          cookLocation: section.cookLocation,
          isVerified: section.isVerified,
          rating: section.rating,
          distanceInKm: section.distanceInKm,
          estimatedTimeMinutes: section.estimatedTimeMinutes,
          totalDishes: filteredDishes.length,
          dishes: filteredDishes,
        );
      }).whereType<CookSectionModel>().toList();
    }

    // Filter by max price
    if (maxPrice != null && maxPrice > 0) {
      filteredSections = filteredSections.map((section) {
        final filteredDishes = section.dishes.where((dish) => dish.price <= maxPrice).toList();
        
        if (filteredDishes.isEmpty) return null;

        return CookSectionModel(
          cookId: section.cookId,
          cookName: section.cookName,
          cookPhotoUrl: section.cookPhotoUrl,
          cookAddress: section.cookAddress,
          cookLocation: section.cookLocation,
          isVerified: section.isVerified,
          rating: section.rating,
          distanceInKm: section.distanceInKm,
          estimatedTimeMinutes: section.estimatedTimeMinutes,
          totalDishes: filteredDishes.length,
          dishes: filteredDishes,
        );
      }).whereType<CookSectionModel>().toList();
    }

    // Sort sections
    if (sortBy != null) {
      switch (sortBy) {
        case 'nearest':
          filteredSections.sort((a, b) {
            final distA = a.distanceInKm ?? double.infinity;
            final distB = b.distanceInKm ?? double.infinity;
            return distA.compareTo(distB);
          });
          break;
        case 'fastest':
          filteredSections.sort((a, b) {
            final timeA = a.estimatedTimeMinutes ?? 999;
            final timeB = b.estimatedTimeMinutes ?? 999;
            return timeA.compareTo(timeB);
          });
          break;
        case 'recommended':
        default:
          // Sort by rating (highest first)
          filteredSections.sort((a, b) {
            final ratingA = a.rating ?? 0.0;
            final ratingB = b.rating ?? 0.0;
            return ratingB.compareTo(ratingA);
          });
          break;
      }
    }

    return filteredSections;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Order types for pricing differentiation
enum OrderType {
  NORMAL_FOOD,  // Regular food delivery - distance-based pricing
  TIFFIN,       // Tiffin service - flat rate pricing
}

/// Delivery Pricing Service - Distance-based calculation with tiered pricing
class PricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default pricing configuration (admin configurable via Firestore)
  static const double DEFAULT_BASE_CHARGE = 25.0;        // ₹25 base charge
  static const double DEFAULT_PER_KM_RATE = 8.0;         // ₹8 per km
  static const double DEFAULT_PETROL_COST_FACTOR = 2.0;  // ₹2 per km

  // Commission split for NORMAL FOOD  
  // Rider: Gets 100% of delivery charge (distance × 8)
  // Platform: Gets 10% of food price as commission
  // Cook: Gets 90% of food price (food price - 10% commission)
  static const double PLATFORM_FOOD_COMMISSION_PERCENT = 10.0; // Platform gets 10% of food price
  
  // Commission split for TIFFIN (different model)
  static const double RIDER_COMMISSION_PERCENT = 80.0;    // Rider gets 80% of delivery charge
  static const double PLATFORM_COMMISSION_PERCENT = 20.0; // Platform gets 20% of delivery charge

  /// Get pricing configuration from Firestore (admin controlled)
  Future<Map<String, double>> getPricingConfig() async {
    try {
      final doc = await _firestore.collection('config').doc('pricing').get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'baseCharge': (data['baseCharge'] as num?)?.toDouble() ?? DEFAULT_BASE_CHARGE,
          'perKmRate': (data['perKmRate'] as num?)?.toDouble() ?? DEFAULT_PER_KM_RATE,
          'petrolCostFactor': (data['petrolCostFactor'] as num?)?.toDouble() ?? DEFAULT_PETROL_COST_FACTOR,
        };
      }

      // Return defaults if not configured
      return {
        'baseCharge': DEFAULT_BASE_CHARGE,
        'perKmRate': DEFAULT_PER_KM_RATE,
        'petrolCostFactor': DEFAULT_PETROL_COST_FACTOR,
      };
    } catch (e) {
      print('❌ Error getting pricing config: $e');
      return {
        'baseCharge': DEFAULT_BASE_CHARGE,
        'perKmRate': DEFAULT_PER_KM_RATE,
        'petrolCostFactor': DEFAULT_PETROL_COST_FACTOR,
      };
    }
  }

  /// Calculate delivery charge based on distance and order type
  /// 
  /// PRODUCTION PRICING:
  /// 
  /// NORMAL FOOD:
  /// - deliveryCharge = distanceKm × ₹8
  /// - Rider gets: 100% of delivery charge
  /// - Platform gets: 10% of food price (calculated separately in order creation)
  /// - Cook gets: 90% of food price
  /// 
  /// TIFFIN:
  /// - deliveryCharge = distanceKm × ₹8
  /// - Rider gets: 80% of delivery charge
  /// - Platform gets: 20% of delivery charge
  Future<Map<String, double>> calculateDeliveryCharge(
    double distanceKm, {
    OrderType orderType = OrderType.NORMAL_FOOD,
  }) async {
    try {
      // 🍕 PRODUCTION DISTANCE-BASED PRICING
      // Both normal food and tiffin: distanceKm × ₹8
      final deliveryCharge = distanceKm * 8.0;
      
      // Round to 2 decimal places
      final roundedDeliveryCharge = double.parse(deliveryCharge.toStringAsFixed(2));

      double riderEarning;
      double platformCommission;

      if (orderType == OrderType.NORMAL_FOOD) {
        // NORMAL FOOD: Rider gets 100% of delivery charge
        // Platform commission comes from food price (10%), calculated at order creation
        riderEarning = roundedDeliveryCharge;
        platformCommission = 0.0; // Commission from food price, not delivery charge
        
        print('🍕 [Pricing] NORMAL FOOD order: ${distanceKm.toStringAsFixed(2)} km × ₹8 = ₹${deliveryCharge.toStringAsFixed(2)}');
        print('💰 Delivery Pricing Breakdown:');
        print('   Order Type: NORMAL FOOD');
        print('   Distance: ${distanceKm.toStringAsFixed(2)} km');
        print('   Total Delivery: ₹${roundedDeliveryCharge.toStringAsFixed(2)}');
        print('   Rider Earning (100%): ₹${riderEarning.toStringAsFixed(2)}');
        print('   Platform Commission: From food price (10%), not delivery charge');
      } else {
        // TIFFIN: Rider gets 80%, Platform gets 20% of delivery charge
        riderEarning = roundedDeliveryCharge * (RIDER_COMMISSION_PERCENT / 100);
        platformCommission = roundedDeliveryCharge * (PLATFORM_COMMISSION_PERCENT / 100);
        
        print('🍱 [Pricing] TIFFIN order: ${distanceKm.toStringAsFixed(2)} km × ₹8 = ₹${deliveryCharge.toStringAsFixed(2)}');
        print('💰 Delivery Pricing Breakdown:');
        print('   Order Type: TIFFIN');
        print('   Distance: ${distanceKm.toStringAsFixed(2)} km');
        print('   Total Delivery: ₹${roundedDeliveryCharge.toStringAsFixed(2)}');
        print('   Rider Earning (80%): ₹${riderEarning.toStringAsFixed(2)}');
        print('   Platform Commission (20%): ₹${platformCommission.toStringAsFixed(2)}');
      }

      return {
        'deliveryCharge': roundedDeliveryCharge,
        'riderEarning': double.parse(riderEarning.toStringAsFixed(2)),
        'platformCommission': double.parse(platformCommission.toStringAsFixed(2)),
      };
    } catch (e) {
      print('❌ Error calculating delivery charge: $e');
      
      // Fallback: Use distance-based pricing
      final fallbackCharge = distanceKm * 8.0;
      if (orderType == OrderType.NORMAL_FOOD) {
        return {
          'deliveryCharge': double.parse(fallbackCharge.toStringAsFixed(2)),
          'riderEarning': double.parse(fallbackCharge.toStringAsFixed(2)), // Rider gets 100%
          'platformCommission': 0.0, // From food price
        };
      } else {
        return {
          'deliveryCharge': double.parse(fallbackCharge.toStringAsFixed(2)),
          'riderEarning': double.parse((fallbackCharge * 0.8).toStringAsFixed(2)),
          'platformCommission': double.parse((fallbackCharge * 0.2).toStringAsFixed(2)),
        };
      }
    }
  }

  /// Calculate distance between two GeoPoints (in kilometers)
  double calculateDistance(GeoPoint from, GeoPoint to) {
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );

      final distanceInKm = distanceInMeters / 1000;
      return double.parse(distanceInKm.toStringAsFixed(2));
    } catch (e) {
      print('❌ Error calculating distance: $e');
      return 0.0;
    }
  }

  /// Calculate order total with delivery
  Map<String, double> calculateOrderTotal({
    required double foodTotal,
    required double deliveryCharge,
  }) {
    final subtotal = foodTotal;
    final delivery = deliveryCharge;
    final grandTotal = subtotal + delivery;

    return {
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'deliveryCharge': double.parse(delivery.toStringAsFixed(2)),
      'grandTotal': double.parse(grandTotal.toStringAsFixed(2)),
    };
  }

  /// Get delivery charge estimate for UI display
  Future<String> getDeliveryEstimate(double distanceKm) async {
    if (distanceKm == 0) {
      return 'Calculating...';
    }

    final pricing = await calculateDeliveryCharge(distanceKm);
    final deliveryCharge = pricing['deliveryCharge']!;

    return '₹${deliveryCharge.toStringAsFixed(0)}';
  }

  /// Calculate COD settlement breakdown
  Map<String, double> calculateCODSettlement({
    required double cashCollected,
    required double riderEarning,
  }) {
    // Cash collected = Food total + Delivery charge
    // Rider keeps: riderEarning
    // Rider owes admin: cashCollected - riderEarning

    final pendingSettlement = cashCollected - riderEarning;

    return {
      'cashCollected': double.parse(cashCollected.toStringAsFixed(2)),
      'riderEarning': double.parse(riderEarning.toStringAsFixed(2)),
      'pendingSettlement': double.parse(pendingSettlement.toStringAsFixed(2)),
    };
  }
}

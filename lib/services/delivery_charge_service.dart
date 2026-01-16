import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🚗 DELIVERY CHARGE CALCULATION SERVICE
/// 
/// Calculates delivery charges based on distance between two locations.
/// 
/// Formula:
/// deliveryCharge = baseFare + (distanceInKm × perKmRate)
/// 
/// Example:
/// - Base fare: ₹20
/// - Per KM rate: ₹8
/// - Distance: 5 km
/// - Total: ₹20 + (5 × ₹8) = ₹60

class DeliveryChargeService {
  // 💰 Pricing Configuration
  static const double baseFare = 20.0; // Base delivery charge
  static const double perKmRate = 8.0; // Charge per kilometer
  static const double minCharge = 20.0; // Minimum delivery charge
  static const double maxCharge = 150.0; // Maximum delivery charge (for very long distances)

  /// Calculate distance between two GeoPoints using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(GeoPoint origin, GeoPoint destination) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double lat1 = origin.latitude * math.pi / 180;
    final double lat2 = destination.latitude * math.pi / 180;
    final double dLat = (destination.latitude - origin.latitude) * math.pi / 180;
    final double dLon = (destination.longitude - origin.longitude) * math.pi / 180;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    final double distance = earthRadius * c;
    
    return distance;
  }

  /// Calculate delivery charge based on distance
  /// 
  /// Formula: baseFare + (distanceInKm × perKmRate)
  /// 
  /// Returns delivery charge in rupees
  static double calculateDeliveryCharge(double distanceInKm) {
    // Round distance to 2 decimal places
    final double roundedDistance = double.parse(distanceInKm.toStringAsFixed(2));
    
    // Calculate charge
    double charge = baseFare + (roundedDistance * perKmRate);
    
    // Apply minimum and maximum limits
    if (charge < minCharge) charge = minCharge;
    if (charge > maxCharge) charge = maxCharge;
    
    // Round to nearest rupee
    return charge.roundToDouble();
  }

  /// Calculate both distance and delivery charge
  /// 
  /// Returns a map with:
  /// - distance: Distance in kilometers (double)
  /// - charge: Delivery charge in rupees (double)
  static Map<String, double> calculateDeliveryDetails(
    GeoPoint origin,
    GeoPoint destination,
  ) {
    final double distance = calculateDistance(origin, destination);
    final double charge = calculateDeliveryCharge(distance);
    
    return {
      'distance': double.parse(distance.toStringAsFixed(2)),
      'charge': charge,
    };
  }

  /// Get formatted distance string
  /// 
  /// Example: "5.2 km" or "850 m"
  static String getFormattedDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      // Show in meters if less than 1 km
      final int meters = (distanceInKm * 1000).round();
      return '$meters m';
    } else {
      // Show in km with 1 decimal place
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  /// Get formatted price string
  /// 
  /// Example: "₹50" or "₹125"
  static String getFormattedPrice(double price) {
    return '₹${price.toStringAsFixed(0)}';
  }

  /// Get delivery charge breakdown as string
  /// 
  /// Example:
  /// "Base fare: ₹20
  ///  Distance (5.2 km): ₹42
  ///  Total: ₹62"
  static String getChargeBreakdown(double distanceInKm, double charge) {
    final double distanceCharge = distanceInKm * perKmRate;
    
    return '''Base fare: ${getFormattedPrice(baseFare)}
Distance (${getFormattedDistance(distanceInKm)}): ${getFormattedPrice(distanceCharge)}
Total: ${getFormattedPrice(charge)}''';
  }

  /// Estimate delivery time based on distance
  /// 
  /// Assumes average speed of 25 km/h in city traffic
  /// Returns estimated time in minutes
  static int estimateDeliveryTime(double distanceInKm) {
    const double averageSpeedKmPerHour = 25.0;
    const int preparationTimeMinutes = 10; // Time for rider to reach restaurant + pick up
    
    final double travelTimeHours = distanceInKm / averageSpeedKmPerHour;
    final int travelTimeMinutes = (travelTimeHours * 60).round();
    
    return preparationTimeMinutes + travelTimeMinutes;
  }

  /// Get formatted delivery time
  /// 
  /// Example: "25-30 mins"
  static String getFormattedDeliveryTime(double distanceInKm) {
    final int estimatedMinutes = estimateDeliveryTime(distanceInKm);
    final int minTime = estimatedMinutes - 5;
    final int maxTime = estimatedMinutes + 5;
    
    return '$minTime-$maxTime mins';
  }
}

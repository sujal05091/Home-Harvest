import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';

/// 🗺️ OpenStreetMap Service (FREE - No API keys needed)
/// Handles location tracking and Firestore updates
class OSMMapsService {
  StreamSubscription<Position>? _positionSubscription;

  /// Get current location
  Future<LatLng?> getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Start real-time location updates for delivery partner
  void startLocationUpdates({
    required String deliveryId,
    required Function(LatLng) onLocationUpdate,
  }) {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
        timeLimit: Duration(seconds: 5), // Or every 5 seconds
      ),
    ).listen((Position position) async {
      final LatLng newLocation = LatLng(position.latitude, position.longitude);
      
      // Call callback
      onLocationUpdate(newLocation);

      // Update Firestore
      try {
        await FirebaseFirestore.instance
            .collection('deliveries')
            .doc(deliveryId)
            .update({
          'currentLocation': GeoPoint(position.latitude, position.longitude),
          'lastUpdated': FieldValue.serverTimestamp(),
          'speed': position.speed,
          'heading': position.heading,
        });
      } catch (e) {
        print('Error updating location in Firestore: $e');
      }
    });
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Calculate distance between two points (in kilometers)
  double calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }

  /// Calculate estimated time (rough estimate: 30 km/h avg speed)
  String calculateEstimatedTime(double distanceInKm) {
    const double avgSpeedKmh = 30.0;
    final double hours = distanceInKm / avgSpeedKmh;
    final int minutes = (hours * 60).round();
    
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    
    final int hrs = minutes ~/ 60;
    final int mins = minutes % 60;
    return '${hrs}h ${mins}min';
  }

  /// Listen to delivery partner location updates (for customer tracking)
  Stream<GeoPoint?> listenToDeliveryLocation(String deliveryId) {
    return FirebaseFirestore.instance
        .collection('deliveries')
        .doc(deliveryId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      return data?['currentLocation'] as GeoPoint?;
    });
  }
}

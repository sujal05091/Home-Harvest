import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/rider_location_model.dart';

/// Real-Time Rider Location Service (Swiggy/Zomato Style)
/// Handles continuous GPS updates with validation and safety checks
class RiderLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _updateTimer;
  
  static const String COLLECTION = 'rider_locations';
  static const int UPDATE_INTERVAL_SECONDS = 5; // 5 seconds
  static const double MIN_DISTANCE_METERS = 2; // 🧪 TESTING: 2 meters (change to 10 for production)
  static const double MAX_SPEED_KMH = 120; // Max realistic speed (km/h)
  static const double MAX_JUMP_METERS = 200; // Max instant location jump

  Position? _lastValidPosition;
  DateTime? _lastUpdateTime;

  /// Start real-time location tracking for rider
  /// Called when rider accepts a delivery
  Future<void> startTracking({
    required String riderId,
    required String orderId,
    required Function(RiderLocationModel) onLocationUpdate,
  }) async {
    print('🚴 Starting real-time tracking for rider: $riderId');

    // Check location permission
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    // Stop any existing tracking
    await stopTracking(riderId);

    // Start continuous GPS stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // 🧪 TESTING: Update every 1 meter (change to 10 for production)
        timeLimit: Duration(seconds: UPDATE_INTERVAL_SECONDS),
      ),
    ).listen(
      (Position position) async {
        // Validate GPS position (prevent teleporting/spoofing)
        if (!_isValidPosition(position)) {
          print('⚠️ Invalid GPS position detected - ignoring update');
          return;
        }

        // Check if moved significantly
        if (_lastValidPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastValidPosition!.latitude,
            _lastValidPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          
          if (distance < MIN_DISTANCE_METERS) {
            print('📍 Rider moved only ${distance.toStringAsFixed(1)}m, skipping update');
            return;
          }
        }

        // Update last valid position
        _lastValidPosition = position;
        _lastUpdateTime = DateTime.now();

        // Create location model
        final locationModel = RiderLocationModel(
          riderId: riderId,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed * 3.6, // m/s to km/h
          heading: position.heading,
          orderId: orderId,
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Save to Firestore
        await _saveLocation(locationModel);

        // Callback
        onLocationUpdate(locationModel);

        print('📍 Location updated: (${position.latitude}, ${position.longitude}) - Speed: ${(position.speed * 3.6).toStringAsFixed(1)} km/h');
      },
      onError: (error) {
        print('❌ GPS Error: $error');
      },
    );

    // Backup timer (in case GPS stream fails)
    _updateTimer = Timer.periodic(
      Duration(seconds: UPDATE_INTERVAL_SECONDS),
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          final locationModel = RiderLocationModel(
            riderId: riderId,
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed * 3.6,
            heading: position.heading,
            orderId: orderId,
            updatedAt: DateTime.now(),
            isActive: true,
          );

          await _saveLocation(locationModel);
          onLocationUpdate(locationModel);
        } catch (e) {
          print('❌ Timer update failed: $e');
        }
      },
    );
  }

  /// Stop tracking when delivery is completed
  Future<void> stopTracking(String riderId) async {
    print('🛑 Stopping tracking for rider: $riderId');

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _updateTimer?.cancel();
    _updateTimer = null;

    // Mark rider as inactive
    try {
      await _firestore.collection(COLLECTION).doc(riderId).update({
        'isActive': false,
        'orderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Could not update rider status: $e');
    }
  }

  /// Listen to rider location updates (for customer app)
  Stream<RiderLocationModel?> listenToRiderLocation(String riderId) {
    return _firestore
        .collection(COLLECTION)
        .doc(riderId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      
      try {
        return RiderLocationModel.fromFirestore(snapshot);
      } catch (e) {
        print('❌ Error parsing rider location: $e');
        return null;
      }
    });
  }

  /// Get current rider location (one-time fetch)
  Future<RiderLocationModel?> getRiderLocation(String riderId) async {
    try {
      final doc = await _firestore.collection(COLLECTION).doc(riderId).get();
      if (!doc.exists) return null;
      return RiderLocationModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error fetching rider location: $e');
      return null;
    }
  }

  /// Save location to Firestore
  Future<void> _saveLocation(RiderLocationModel location) async {
    try {
      // Save to rider_locations collection
      await _firestore
          .collection(COLLECTION)
          .doc(location.riderId)
          .set(location.toMap(), SetOptions(merge: true));
      
      // Also update currentLocation in deliveries collection for real-time customer tracking
      if (location.orderId != null) {
        await _firestore
            .collection('deliveries')
            .doc(location.orderId)
            .update({
          'currentLocation': GeoPoint(location.latitude, location.longitude),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error saving location: $e');
      // Don't rethrow to avoid breaking tracking
    }
  }

  /// Validate GPS position to prevent teleporting and spoofing
  /// Returns false if position is suspicious
  bool _isValidPosition(Position position) {
    // First position is always valid
    if (_lastValidPosition == null || _lastUpdateTime == null) {
      return true;
    }

    // Calculate distance from last valid position
    final distance = Geolocator.distanceBetween(
      _lastValidPosition!.latitude,
      _lastValidPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Check for GPS jumps (teleportation)
    if (distance > MAX_JUMP_METERS) {
      print('⚠️ GPS JUMP DETECTED: ${distance.toStringAsFixed(1)}m instant movement');
      return false;
    }

    // Calculate time delta
    final timeDelta = position.timestamp.difference(_lastUpdateTime!).inSeconds;
    if (timeDelta == 0) return true; // Avoid division by zero

    // Calculate speed (m/s to km/h)
    final speedKmh = (distance / timeDelta) * 3.6;

    // Check for unrealistic speed
    if (speedKmh > MAX_SPEED_KMH) {
      print('⚠️ UNREALISTIC SPEED: ${speedKmh.toStringAsFixed(1)} km/h (max: $MAX_SPEED_KMH km/h)');
      return false;
    }

    // Additional checks
    if (position.accuracy > 50) {
      print('⚠️ LOW GPS ACCURACY: ${position.accuracy.toStringAsFixed(1)}m');
      return false;
    }

    return true;
  }

  /// Check location permission
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Calculate ETA based on distance and average speed
  String calculateETA(double distanceKm, {double avgSpeedKmh = 25.0}) {
    if (distanceKm < 0.1) return 'Arriving now';
    
    final timeHours = distanceKm / avgSpeedKmh;
    final timeMinutes = (timeHours * 60).ceil();
    
    if (timeMinutes < 1) return 'Less than a minute';
    if (timeMinutes < 60) return '$timeMinutes min';
    
    final hours = timeMinutes ~/ 60;
    final minutes = timeMinutes % 60;
    return '${hours}h ${minutes}min';
  }

  /// Calculate distance between two points
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final distanceMeters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return distanceMeters / 1000; // Convert to km
  }
}

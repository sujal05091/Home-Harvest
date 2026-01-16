import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery_model.dart';
import '../services/firestore_service.dart';

class RiderProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<DeliveryModel> _activeDeliveries = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAvailable = true;

  List<DeliveryModel> get activeDeliveries => _activeDeliveries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _isAvailable;

  // Load rider deliveries
  void loadRiderDeliveries(String riderId) {
    _isLoading = true;
    notifyListeners();

    _firestoreService.getRiderDeliveries(riderId).listen(
      (deliveries) {
        _activeDeliveries = deliveries;
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

  // Update delivery status
  Future<bool> updateDeliveryStatus(
    String deliveryId,
    DeliveryStatus newStatus,
  ) async {
    try {
      int index = _activeDeliveries.indexWhere(
        (delivery) => delivery.deliveryId == deliveryId,
      );

      if (index != -1) {
        DeliveryModel updatedDelivery = _activeDeliveries[index].copyWith(
          status: newStatus,
          acceptedAt: newStatus == DeliveryStatus.ACCEPTED
              ? DateTime.now()
              : _activeDeliveries[index].acceptedAt,
          pickedUpAt: newStatus == DeliveryStatus.PICKED_UP
              ? DateTime.now()
              : _activeDeliveries[index].pickedUpAt,
          deliveredAt: newStatus == DeliveryStatus.DELIVERED
              ? DateTime.now()
              : _activeDeliveries[index].deliveredAt,
        );

        await _firestoreService.updateDelivery(updatedDelivery);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Update rider location (for real-time tracking)
  Future<bool> updateRiderLocation(
    String deliveryId,
    double lat,
    double lng,
  ) async {
    try {
      int index = _activeDeliveries.indexWhere(
        (delivery) => delivery.deliveryId == deliveryId,
      );

      if (index != -1) {
        DeliveryModel updatedDelivery = _activeDeliveries[index].copyWith(
          currentLocation: GeoPoint(lat, lng),
        );

        await _firestoreService.updateDelivery(updatedDelivery);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Toggle availability and save to Firestore
  Future<void> toggleAvailability() async {
    _isAvailable = !_isAvailable;
    notifyListeners();
    
    // 🔔 Save isOnline status to Firestore (CRITICAL for FCM notifications!)
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'isOnline': _isAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        print('✅ Rider ${_isAvailable ? "ONLINE" : "OFFLINE"} status saved to Firestore');
      }
    } catch (e) {
      print('⚠️ Failed to save online status: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

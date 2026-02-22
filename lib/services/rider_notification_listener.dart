import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// 🔔 NOTIFICATION LISTENER SERVICE
/// Listens for new delivery request notifications in Firestore
/// Marks notifications as read automatically
class RiderNotificationListener {
  static final RiderNotificationListener _instance = RiderNotificationListener._internal();
  factory RiderNotificationListener() => _instance;
  RiderNotificationListener._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  Set<String> _processedNotifications = <String>{};
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the listener with navigator key
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    print('📡 [NotificationListener] Initialized with navigator key');
  }

  /// Start listening for delivery request notifications
  Future<void> startListening() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      print('⚠️ [NotificationListener] No user logged in, cannot start listening');
      return;
    }

    // Check user role
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userRole = userDoc.data()?['role'];

    if (userRole != 'rider') {
      print('ℹ️ [NotificationListener] User is not a rider (role: $userRole), skipping notification listener');
      return;
    }

    print('🚀 [NotificationListener] Starting to listen for rider: ${currentUser.uid}');
    print('📡 [NotificationListener] Query: notifications where recipientId==${currentUser.uid} AND type==NEW_DELIVERY_REQUEST AND read==false');

    // Cancel existing subscription if any
    await stopListening();

    // Listen for new notifications addressed to this rider
    // Simplified query (no orderBy) to avoid needing Firestore composite index
    _notificationSubscription = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('type', isEqualTo: 'NEW_DELIVERY_REQUEST')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        print('📩 [NotificationListener] Snapshot received with ${snapshot.docs.length} documents');
        _handleNotificationSnapshot(snapshot);
      },
      onError: (error) {
        print('❌ [NotificationListener] Error: $error');
      },
    );

    print('✅ [NotificationListener] Listening started successfully');
  }

  /// Stop listening
  Future<void> stopListening() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _processedNotifications.clear();
    print('🛑 [NotificationListener] Stopped listening');
  }

  /// Handle notification snapshot
  void _handleNotificationSnapshot(QuerySnapshot snapshot) {
    print('📩 [NotificationListener] Received ${snapshot.docs.length} notifications');
    print('📊 [NotificationListener] Document changes: ${snapshot.docChanges.length}');

    for (var change in snapshot.docChanges) {
      print('🔄 [NotificationListener] Change type: ${change.type}');
      
      if (change.type == DocumentChangeType.added) {
        final notificationId = change.doc.id;
        
        // Skip if already processed
        if (_processedNotifications.contains(notificationId)) {
          print('⏭️ [NotificationListener] Already processed: $notificationId');
          continue;
        }

        _processedNotifications.add(notificationId);
        
        final data = change.doc.data() as Map<String, dynamic>;
        print('🆕 [NotificationListener] New notification:');
        print('   ID: $notificationId');
        print('   Type: ${data['type']}');
        print('   Order ID: ${data['orderId']}');
        print('   Recipient ID: ${data['recipientId']}');
        print('   Read: ${data['read']}');
        
        _handleNewNotification(notificationId, data);
      }
    }
  }

  /// Handle new notification and mark as read
  Future<void> _handleNewNotification(
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    try {
      final orderId = data['orderId'] as String?;
      
      if (orderId == null) {
        print('⚠️ [NotificationListener] No orderId in notification');
        return;
      }

      print('🍽️ [NotificationListener] Processing delivery request for order: $orderId');

      // Mark notification as read - rider will see in available orders list
      await _markNotificationAsRead(notificationId);
    } catch (e) {
      print('❌ [NotificationListener] Error handling notification: $e');
    }
  }

  /// Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ [NotificationListener] Marked notification as read: $notificationId');
    } catch (e) {
      print('⚠️ [NotificationListener] Error marking notification as read: $e');
    }
  }

  /// Resume listening after app comes back to foreground
  Future<void> resume() async {
    print('🔄 [NotificationListener] Resuming...');
    await startListening();
  }

  /// Pause listening when app goes to background
  Future<void> pause() async {
    print('⏸️ [NotificationListener] Pausing...');
    // Don't stop completely, just clear processed list to catch new notifications
    _processedNotifications.clear();
  }
}

/**
 * ════════════════════════════════════════════════════════════════════════════
 * 🚀 HOMEHARVEST - REAL-TIME DELIVERY NOTIFICATION CLOUD FUNCTIONS
 * ════════════════════════════════════════════════════════════════════════════
 * 
 * This Cloud Function sends FCM notifications to nearby riders when a new order
 * is placed. It implements smart retry logic and one-by-one notification.
 * 
 * SETUP INSTRUCTIONS:
 * 1. cd functions
 * 2. npm install
 * 3. firebase deploy --only functions
 * 
 * ════════════════════════════════════════════════════════════════════════════
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * 🔥 CLOUD FUNCTION: Send FCM notification to rider when order is assigned
 * Triggers when order document is created or updated
 */
exports.notifyRiderOnOrderAssignment = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const newData = change.after.data();
    const oldData = change.before.data();
    
    // Only trigger if rider was just assigned
    if (!oldData.assignedRiderId && newData.assignedRiderId) {
      console.log(`📦 Order ${orderId} assigned to rider: ${newData.assignedRiderId}`);
      
      try {
        // Get rider's FCM token
        const riderDoc = await admin.firestore()
          .collection('users')
          .doc(newData.assignedRiderId)
          .get();
        
        if (!riderDoc.exists) {
          console.log(`❌ Rider ${newData.assignedRiderId} not found`);
          return null;
        }
        
        const riderData = riderDoc.data();
        const fcmToken = riderData.fcmToken;
        
        if (!fcmToken) {
          console.log(`❌ Rider ${newData.assignedRiderId} has no FCM token`);
          return null;
        }
        
        // 🚀 Send FCM notification with BOTH notification + data payload
        const message = {
          notification: {
            title: '🚀 New Delivery Request',
            body: `Pickup from ${newData.pickupAddress}. Tap to accept.`,
          },
          data: {
            orderId: orderId,
            type: 'NEW_DELIVERY_REQUEST',
            pickupAddress: newData.pickupAddress || '',
            dropAddress: newData.dropAddress || '',
            status: newData.status || '',
          },
          token: fcmToken,
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'delivery_requests_channel',
              priority: 'max',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };
        
        const response = await admin.messaging().send(message);
        console.log(`✅ Notification sent successfully: ${response}`);
        
        // Update order with notification status
        await change.after.ref.update({
          notificationSent: true,
          notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        return response;
      } catch (error) {
        console.error(`❌ Error sending notification: ${error}`);
        
        // Log error to Firestore for debugging
        await admin.firestore().collection('notification_errors').add({
          orderId: orderId,
          riderId: newData.assignedRiderId,
          error: error.message,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        return null;
      }
    }
    
    return null;
  });

/**
 * 🔔 CLOUD FUNCTION: Notify nearby riders when new order is placed
 * Finds riders within 5km radius and sends notifications
 */
exports.notifyNearbyRiders = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data();
    
    console.log(`📦 New order created: ${orderId}`);
    
    try {
      // Get all online riders
      const ridersSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'rider')
        .where('isOnline', '==', true)
        .get();
      
      if (ridersSnapshot.empty) {
        console.log('❌ No online riders found');
        return null;
      }
      
      console.log(`📊 Found ${ridersSnapshot.size} online riders`);
      
      // Prepare notification messages for all riders
      const messages = [];
      
      ridersSnapshot.forEach((riderDoc) => {
        const riderData = riderDoc.data();
        const fcmToken = riderData.fcmToken;
        
        if (fcmToken) {
          messages.push({
            notification: {
              title: '🚀 New Delivery Request',
              body: `Pickup from ${orderData.pickupAddress}. Tap to view.`,
            },
            data: {
              orderId: orderId,
              type: 'NEW_DELIVERY_REQUEST',
              pickupAddress: orderData.pickupAddress || '',
              dropAddress: orderData.dropAddress || '',
            },
            token: fcmToken,
            android: {
              priority: 'high',
              notification: {
                channelId: 'delivery_requests_channel',
              },
            },
          });
        }
      });
      
      if (messages.length === 0) {
        console.log('❌ No riders with valid FCM tokens');
        return null;
      }
      
      // Send notifications to all riders
      const response = await admin.messaging().sendEach(messages);
      console.log(`✅ Sent ${response.successCount} notifications to riders`);
      
      // Update order with notification stats
      await snapshot.ref.update({
        notificationsSent: response.successCount,
        notificationsFailed: response.failureCount,
        notificationsSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return response;
    } catch (error) {
      console.error(`❌ Error notifying nearby riders: ${error}`);
      return null;
    }
  });

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * ────────────────────────────────────────────────────────────────────────────
 * 📍 FUNCTION 1: Find Nearby Riders
 * ────────────────────────────────────────────────────────────────────────────
 * Triggered when order status changes to PLACED
 */
exports.notifyNearbyRiders = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;

    console.log(`🆕 New order created: ${orderId}`);

    // Only process PLACED orders
    if (order.status !== 'PLACED') {
      console.log(`⏭️ Order status is ${order.status}, skipping notification`);
      return null;
    }

    try {
      // Get pickup location
      const pickupLat = order.pickupLocation.latitude;
      const pickupLng = order.pickupLocation.longitude;

      // Find online riders within 5km radius
      const ridersSnapshot = await db.collection('users')
        .where('role', '==', 'rider')
        .where('isOnline', '==', true)
        .get();

      if (ridersSnapshot.empty) {
        console.log('❌ No online riders found');
        await snap.ref.update({ 
          status: 'NO_RIDERS_AVAILABLE',
          searchStartedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
      }

      // Calculate distances and sort by nearest
      const riders = [];
      ridersSnapshot.forEach(doc => {
        const rider = doc.data();
        const riderLat = rider.currentLocation?.latitude;
        const riderLng = rider.currentLocation?.longitude;
        
        if (riderLat && riderLng && rider.fcmToken) {
          const distance = calculateDistance(pickupLat, pickupLng, riderLat, riderLng);
          if (distance <= 5) { // Within 5km
            riders.push({
              id: doc.id,
              name: rider.fullName,
              phone: rider.phone,
              fcmToken: rider.fcmToken,
              distance: distance
            });
          }
        }
      });

      if (riders.length === 0) {
        console.log('❌ No riders within 5km radius');
        await snap.ref.update({ status: 'NO_NEARBY_RIDERS' });
        return null;
      }

      // Sort by distance (nearest first)
      riders.sort((a, b) => a.distance - b.distance);
      console.log(`✅ Found ${riders.length} nearby riders`);

      // Send notification to all riders (they can accept/reject)
      const notifications = riders.map(rider => ({
        token: rider.fcmToken,
        notification: {
          title: '🔔 New Delivery Request',
          body: `${order.customerName} • ${rider.distance.toFixed(1)}km away`,
        },
        data: {
          type: 'delivery_request',
          orderId: orderId,
          customerName: order.customerName || 'Customer',
          pickupAddress: order.pickupAddress || 'Pickup Location',
          dropAddress: order.dropAddress || 'Drop Location',
          distance: rider.distance.toFixed(1),
          earnings: (order.total * 0.10).toFixed(0),
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'delivery_requests',
            priority: 'max',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      }));

      // Send all notifications
      const results = await Promise.allSettled(
        notifications.map(msg => messaging.send(msg))
      );

      let successCount = 0;
      let failCount = 0;
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          successCount++;
          console.log(`✅ Notification sent to ${riders[index].name}`);
        } else {
          failCount++;
          console.error(`❌ Failed to send to ${riders[index].name}:`, result.reason);
        }
      });

      console.log(`📊 Notifications: ${successCount} sent, ${failCount} failed`);

      // Update order with notification status
      await snap.ref.update({
        notifiedRiders: riders.map(r => r.id),
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        searchStartedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return { success: successCount, failed: failCount };

    } catch (error) {
      console.error('❌ Error in notifyNearbyRiders:', error);
      return null;
    }
  });

/**
 * ────────────────────────────────────────────────────────────────────────────
 * 🔄 FUNCTION 2: Retry Logic (if no response in 30 seconds)
 * ────────────────────────────────────────────────────────────────────────────
 */
exports.retryRiderNotification = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Check if order is still in PLACED status after searchStartedAt
    if (after.status === 'PLACED' && after.searchStartedAt) {
      const searchStartedAt = after.searchStartedAt.toDate();
      const now = new Date();
      const elapsedSeconds = (now - searchStartedAt) / 1000;

      // If 30 seconds passed and no rider accepted
      if (elapsedSeconds > 30 && !after.assignedRiderId) {
        console.log(`⏰ 30 seconds elapsed for order ${orderId}, retrying...`);

        // Find riders who haven't rejected yet
        const rejectedRiders = after.rejectedBy || [];
        const ridersSnapshot = await db.collection('users')
          .where('role', '==', 'rider')
          .where('isOnline', '==', true)
          .get();

        const availableRiders = [];
        ridersSnapshot.forEach(doc => {
          if (!rejectedRiders.includes(doc.id) && doc.data().fcmToken) {
            availableRiders.push({
              id: doc.id,
              token: doc.data().fcmToken,
              name: doc.data().fullName
            });
          }
        });

        if (availableRiders.length > 0) {
          // Send reminder notifications
          const notifications = availableRiders.map(rider => ({
            token: rider.token,
            notification: {
              title: '⚠️ Still Looking!',
              body: `Order from ${after.customerName} needs a rider URGENTLY!`,
            },
            data: {
              type: 'delivery_request',
              orderId: orderId,
              isRetry: 'true'
            }
          }));

          await Promise.allSettled(
            notifications.map(msg => messaging.send(msg))
          );

          console.log(`📢 Retry notifications sent to ${availableRiders.length} riders`);

          // Update searchStartedAt to prevent multiple retries
          await change.after.ref.update({
            searchStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            retryCount: (after.retryCount || 0) + 1
          });
        }
      }
    }

    return null;
  });

/**
 * ────────────────────────────────────────────────────────────────────────────
 * 🚫 FUNCTION 3: Handle Rider Acceptance (Stop Notifications)
 * ────────────────────────────────────────────────────────────────────────────
 */
exports.onRiderAcceptance = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // If status changed to RIDER_ACCEPTED
    if (before.status !== 'RIDER_ACCEPTED' && after.status === 'RIDER_ACCEPTED') {
      console.log(`✅ Order ${context.params.orderId} accepted by ${after.assignedRiderName}`);

      // Send confirmation to customer
      if (after.customerId) {
        const customerDoc = await db.collection('users').doc(after.customerId).get();
        const customerToken = customerDoc.data()?.fcmToken;

        if (customerToken) {
          await messaging.send({
            token: customerToken,
            notification: {
              title: '🎉 Rider Found!',
              body: `${after.assignedRiderName} is picking up your order`,
            },
            data: {
              type: 'rider_accepted',
              orderId: context.params.orderId
            }
          });
        }
      }
    }

    return null;
  });

/**
 * ────────────────────────────────────────────────────────────────────────────
 * 📏 HELPER: Calculate Distance (Haversine Formula)
 * ────────────────────────────────────────────────────────────────────────────
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in km
}

function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🐛 DEBUG: Test Notification Listener
/// Shows notifications in Firestore for debugging
class DebugNotificationsScreen extends StatelessWidget {
  const DebugNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🐛 Debug: Notifications'),
        backgroundColor: Colors.purple,
      ),
      body: currentUser == null
          ? const Center(child: Text('Not logged in'))
          : Column(
              children: [
                // User info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current User ID: ${currentUser.uid}'),
                      const SizedBox(height: 8),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text('Loading...');
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: ${data?['name'] ?? 'N/A'}'),
                              Text('Role: ${data?['role'] ?? 'N/A'}'),
                              Text('Online: ${data?['isOnline'] ?? false}'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Notifications list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('recipientId', isEqualTo: currentUser.uid)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No notifications found'),
                              SizedBox(height: 8),
                              Text(
                                'Have a cook mark food as ready',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                          final read = data['read'] ?? false;

                          return Card(
                            color: read ? Colors.grey[100] : Colors.white,
                            child: ListTile(
                              leading: Icon(
                                read ? Icons.mark_email_read : Icons.mark_email_unread,
                                color: read ? Colors.grey : Colors.orange,
                              ),
                              title: Text(
                                data['title'] ?? 'No title',
                                style: TextStyle(
                                  fontWeight: read ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['body'] ?? 'No body'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Order: ${data['orderId'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'Type: ${data['type'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      'Created: ${createdAt.toString().substring(0, 19)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ],
                              ),
                              trailing: read
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.circle, color: Colors.red),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // All notifications (any recipient)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange[100],
                  child: const Text(
                    '📊 ALL NOTIFICATIONS (Debug)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No notifications in database'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return Card(
                            child: ListTile(
                              title: Text(data['title'] ?? 'No title'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Recipient: ${data['recipientId'] ?? 'N/A'}'),
                                  Text('Order: ${data['orderId'] ?? 'N/A'}'),
                                  Text('Type: ${data['type'] ?? 'N/A'}'),
                                  Text('Read: ${data['read'] ?? false}'),
                                ],
                              ),
                              trailing: Text(
                                data['recipientId'] == currentUser.uid ? '👤 YOU' : '',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

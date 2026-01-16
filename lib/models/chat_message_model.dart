import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, location }

class ChatMessageModel {
  final String messageId;
  final String orderId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String message;
  final MessageType type;
  final String? imageUrl;
  final GeoPoint? location;
  final DateTime timestamp;
  final bool isRead;

  ChatMessageModel({
    required this.messageId,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.message,
    this.type = MessageType.text,
    this.imageUrl,
    this.location,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'orderId': orderId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'message': message,
      'type': type.name,
      'imageUrl': imageUrl,
      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      messageId: map['messageId'] ?? '',
      orderId: map['orderId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      imageUrl: map['imageUrl'],
      location: map['location'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  ChatMessageModel copyWith({
    String? messageId,
    String? orderId,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? message,
    MessageType? type,
    String? imageUrl,
    GeoPoint? location,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessageModel(
      messageId: messageId ?? this.messageId,
      orderId: orderId ?? this.orderId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

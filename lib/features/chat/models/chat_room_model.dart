import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String userId;
  final String userName;
  final String lastMessageText;
  final Timestamp lastMessageTimestamp;
  final bool isReadBySupport;

  ChatRoom({
    required this.userId,
    required this.userName,
    required this.lastMessageText,
    required this.lastMessageTimestamp,
    required this.isReadBySupport,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      userId: doc.id,
      userName: data['userName'] ?? 'Unknown User',
      lastMessageText: data['lastMessageText'] ?? '',
      lastMessageTimestamp: data['lastMessageTimestamp'] ?? Timestamp.now(),
      isReadBySupport: data['isReadBySupport'] ?? true,
    );
  }
}
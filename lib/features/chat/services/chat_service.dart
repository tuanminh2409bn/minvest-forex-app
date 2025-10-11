import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minvest_forex_app/features/chat/models/chat_message_model.dart';
import 'package:minvest_forex_app/features/chat/models/chat_room_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy stream tin nhắn cho một phòng chat cụ thể
  Stream<List<ChatMessage>> getMessagesStream(String userId) {
    return _firestore
        .collection('chat_rooms')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    });
  }

  // Gửi một tin nhắn
  Future<void> sendMessage({
    required String userId,
    required String text,
    required String senderId,
    required String senderName,
  }) async {
    if (text.trim().isEmpty) return;

    final timestamp = Timestamp.now();
    final message = ChatMessage(
      id: '', // ID sẽ được Firestore tự tạo
      text: text,
      senderId: senderId,
      senderName: senderName,
      timestamp: timestamp,
    );

    final chatRoomRef = _firestore.collection('chat_rooms').doc(userId);
    final messagesRef = chatRoomRef.collection('messages');

    await _firestore.runTransaction((transaction) async {
      // Thêm tin nhắn mới vào subcollection
      transaction.set(messagesRef.doc(), message.toFirestore());

      // Cập nhật thông tin của phòng chat (tin nhắn cuối cùng, thời gian,...)
      transaction.set(
        chatRoomRef,
        {
          'userId': userId,
          'userName': senderName, // Giả sử người dùng là người bắt đầu chat
          'lastMessageText': text,
          'lastMessageTimestamp': timestamp,
          'lastMessageSenderId': senderId,
          'isReadBySupport': false, // Khi người dùng gửi, support chưa đọc
          'isReadByUser': true,
        },
        SetOptions(merge: true), // Dùng merge để không ghi đè các trường khác
      );
    });
  }

  // (Dành cho Support) Lấy stream của tất cả các phòng chat
  Stream<List<ChatRoom>> getChatRoomsStream() {
    return _firestore
        .collection('chat_rooms')
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList();
    });
  }
}
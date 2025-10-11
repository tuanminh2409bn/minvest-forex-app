import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/chat/models/chat_message_model.dart';
import 'package:minvest_forex_app/features/chat/services/chat_service.dart';

class SupportChatScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const SupportChatScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    // Lấy thông tin của nhân viên support đang đăng nhập
    final supportUser = FirebaseAuth.instance.currentUser;

    if (_messageController.text.isNotEmpty && supportUser != null) {
      _chatService.sendMessage(
        userId: widget.userId, // ID phòng chat là của khách hàng
        text: _messageController.text,
        senderId: supportUser.uid, // Người gửi là nhân viên support
        senderName: supportUser.displayName ?? 'Hỗ trợ',
      );
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportUser = FirebaseAuth.instance.currentUser;
    if (supportUser == null) return const Scaffold(); // Trường hợp hiếm gặp

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(widget.userName), // Tên của khách hàng
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesStream(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Chưa có tin nhắn nào.'));
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16.0),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    // Tin nhắn "của tôi" là tin nhắn do nhân viên support gửi
                    final isMyMessage = message.senderId == supportUser.uid;
                    return _buildMessageBubble(message, isMyMessage);
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMyMessage) {
    return Row(
      mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isMyMessage ? const Color(0xFF005D4B) : const Color(0xFF2A2D3A), // Màu khác cho support
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                filled: true,
                fillColor: const Color(0xFF2A2D3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blueAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minvest_forex_app/features/chat/models/chat_room_model.dart';
import 'package:minvest_forex_app/features/chat/screens/support_chat_screen.dart';
import 'package:minvest_forex_app/features/chat/services/chat_service.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';

class SupportDashboardScreen extends StatefulWidget {
  const SupportDashboardScreen({super.key});

  @override
  State<SupportDashboardScreen> createState() => _SupportDashboardScreenState();
}

class _SupportDashboardScreenState extends State<SupportDashboardScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(l10n.tabChat),
        automaticallyImplyLeading: false, // Ẩn nút back
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: _chatService.getChatRoomsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có cuộc trò chuyện nào',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final chatRooms = snapshot.data!;

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final room = chatRooms[index];
              return _buildChatRoomTile(room);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatRoomTile(ChatRoom room) {
    // Định dạng thời gian cho dễ đọc
    final String formattedTime =
    DateFormat('HH:mm dd/MM').format(room.lastMessageTimestamp.toDate());

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueGrey,
        child: Text(
          room.userName.isNotEmpty ? room.userName[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        room.userName,
        style: TextStyle(
          fontWeight: !room.isReadBySupport ? FontWeight.bold : FontWeight.normal,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        room.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: !room.isReadBySupport ? Colors.white70 : Colors.grey,
        ),
      ),
      trailing: Text(
        formattedTime,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      onTap: () {
        // Điều hướng đến màn hình chat chi tiết của user này
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SupportChatScreen(
              userId: room.userId,
              userName: room.userName,
            ),
          ),
        );
      },
    );
  }
}
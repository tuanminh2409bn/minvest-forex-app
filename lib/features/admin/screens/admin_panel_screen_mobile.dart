// lib/features/admin/screens/admin_panel_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:minvest_forex_app/features/admin/services/admin_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminService _adminService = AdminService();
  // Dùng Set để lưu các userId được chọn, giúp tránh trùng lặp
  final Set<String> _selectedUserIds = {};
  final TextEditingController _reasonController = TextEditingController();

  // Hàm xử lý khi nhấn nút Khóa
  void _handleSuspendUsers() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một tài khoản.')),
      );
      return;
    }

    // Hiển thị dialog để Admin nhập lý do
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập lý do khóa tài khoản'),
        content: TextField(
          controller: _reasonController,
          decoration: const InputDecoration(hintText: 'Lý do...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lý do không được để trống.')),
                );
                return;
              }

              Navigator.of(context).pop(); // Đóng dialog
              _executeAction(status: 'suspended', reason: reason);
            },
            child: const Text('Xác nhận khóa'),
          ),
        ],
      ),
    );
  }

  // Hàm xử lý khi nhấn nút Mở khóa
  void _handleActivateUsers() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một tài khoản.')),
      );
      return;
    }
    _executeAction(status: 'active');
  }

  // Hàm chung để gọi Cloud Function
  Future<void> _executeAction({required String status, String? reason}) async {
    final message = await _adminService.manageUserStatus(
      userIds: _selectedUserIds.toList(),
      newStatus: status,
      reason: reason,
    );

    // Xóa các lựa chọn và hiển thị kết quả
    setState(() {
      _selectedUserIds.clear();
    });
    _reasonController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng quản lý Admin'),
        // Nút để bỏ chọn tất cả
        actions: [
          if (_selectedUserIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() => _selectedUserIds.clear()),
              tooltip: 'Bỏ chọn tất cả',
            )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lấy danh sách tất cả người dùng
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không có người dùng nào.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final userId = userDoc.id;

              final displayName = userData['displayName'] ?? 'N/A';
              final email = userData['email'] ?? 'N/A';
              final role = userData['role'] ?? 'user';
              final isSuspended = userData['isSuspended'] ?? false;
              final isSelected = _selectedUserIds.contains(userId);

              return Container(
                color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                child: ListTile(
                  // Checkbox để chọn
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedUserIds.add(userId);
                        } else {
                          _selectedUserIds.remove(userId);
                        }
                      });
                    },
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      color: isSuspended ? Colors.red : (role == 'admin' ? Colors.amber : null),
                      fontWeight: role == 'admin' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(email),
                  // Hiển thị vai trò và trạng thái
                  trailing: Text(
                    role == 'admin' ? 'Admin' : (isSuspended ? 'Bị khóa' : 'Active'),
                    style: TextStyle(
                        color: isSuspended ? Colors.red.shade300 : Colors.green.shade300,
                        fontStyle: FontStyle.italic
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // Thanh hành động ở dưới cùng
      bottomNavigationBar: _selectedUserIds.isNotEmpty
          ? BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleActivateUsers,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Mở khóa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleSuspendUsers,
                  icon: const Icon(Icons.lock),
                  label: const Text('Khóa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }
}
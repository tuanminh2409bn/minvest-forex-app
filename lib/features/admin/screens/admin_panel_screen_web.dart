// lib/features/admin/screens/admin_panel_screen_web.dart

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
  final Set<String> _selectedUserIds = {};
  final TextEditingController _reasonController = TextEditingController();

  // --- CÁC HÀM LOGIC GIỮ NGUYÊN ---
  void _handleSuspendUsers() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một tài khoản.')),
      );
      return;
    }
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(context).pop();
              _executeAction(status: 'suspended', reason: reason);
            },
            child: const Text('Xác nhận khóa'),
          ),
        ],
      ),
    );
  }

  void _handleActivateUsers() {
    if (_selectedUserIds.isEmpty) return;
    _executeAction(status: 'active');
  }

  Future<void> _executeAction({required String status, String? reason}) async {
    final message = await _adminService.manageUserStatus(
      userIds: _selectedUserIds.toList(),
      newStatus: status,
      reason: reason,
    );
    setState(() => _selectedUserIds.clear());
    _reasonController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
  // --- KẾT THÚC CÁC HÀM LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bảng quản lý Admin (${_selectedUserIds.length} đã chọn)'),
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
        stream: FirebaseFirestore.instance.collection('users').orderBy('displayName').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không có người dùng nào.'));
          }

          final userDocs = snapshot.data!.docs;

          // ▼▼▼ SỬ DỤNG DATATABLE CHO GIAO DIỆN WEB ▼▼▼
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              showCheckboxColumn: true,
              columns: const [
                DataColumn(label: Text('Tên hiển thị')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Hạng')),
                DataColumn(label: Text('Vai trò')),
                DataColumn(label: Text('Trạng thái')),
              ],
              rows: userDocs.map((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                final userId = doc.id;
                final isSelected = _selectedUserIds.contains(userId);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedUserIds.add(userId);
                      } else {
                        _selectedUserIds.remove(userId);
                      }
                    });
                  },
                  cells: [
                    DataCell(Text(userData['displayName'] ?? 'N/A')),
                    DataCell(Text(userData['email'] ?? 'N/A')),
                    DataCell(Text(userData['subscriptionTier']?.toUpperCase() ?? 'FREE')),
                    DataCell(Text(
                      userData['role'] ?? 'user',
                      style: TextStyle(
                        fontWeight: userData['role'] == 'admin' ? FontWeight.bold : FontWeight.normal,
                        color: userData['role'] == 'admin' ? Colors.amber : Colors.white,
                      ),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (userData['isSuspended'] ?? false) ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (userData['isSuspended'] ?? false) ? 'Bị khóa' : 'Active',
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
      // --- THANH HÀNH ĐỘNG CHO WEB ---
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _handleActivateUsers,
            label: const Text('Mở khóa'),
            icon: const Icon(Icons.lock_open),
            backgroundColor: Colors.green,
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _handleSuspendUsers,
            label: const Text('Khóa'),
            icon: const Icon(Icons.lock),
            backgroundColor: Colors.red,
          ),
        ],
      )
          : null,
    );
  }
}
// lib/features/admin/screens/admin_panel_screen_web.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  void _handleDowngradeUsers() {
    if (_selectedUserIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hạ cấp tài khoản về Free'),
        content: TextField(controller: _reasonController, decoration: const InputDecoration(hintText: 'Nhập lý do hạ cấp (bắt buộc)...'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(context).pop();
              _executeDowngradeAction(reason: reason);
            },
            child: const Text('Xác nhận hạ cấp'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDowngradeAction({required String reason}) async {
    final message = await _adminService.downgradeUsersToFree(
        userIds: _selectedUserIds.toList(),
        reason: reason
    );
    setState(() => _selectedUserIds.clear());
    _reasonController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatPayment(dynamic amount) {
    if (amount == null || amount is! num || amount == 0) {
      return 'N/A';
    }
    final format = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '',
        decimalDigits: 0
    );
    return '\$${format.format(amount)}'.trim();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bảng quản lý Admin (${_selectedUserIds.length} đã chọn)'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear_all), onPressed: () => setState(() => _selectedUserIds.clear()), tooltip: 'Bỏ chọn tất cả')
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

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: true,
                columns: const [
                  DataColumn(label: Text('Tên & Email')),
                  DataColumn(label: Text('Group')),
                  DataColumn(label: Text('Trạng thái')),
                  DataColumn(label: Text('Lý do hạ cấp')),
                  DataColumn(label: Text('Payment')),
                  DataColumn(label: Text('Mobile UID')),
                  DataColumn(label: Text('Exness Client UID')),
                  DataColumn(label: Text('Exness Account')),
                  DataColumn(label: Text('Ngày tạo')),
                  DataColumn(label: Text('Ngày hết hạn')),
                ],
                rows: userDocs.map((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final userId = doc.id;
                  final isSelected = _selectedUserIds.contains(userId);
                  final Timestamp? createdAt = userData['createdAt'];
                  final Timestamp? expiryDate = userData['subscriptionExpiryDate'];

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) {
                      setState(() {
                        if (selected == true) _selectedUserIds.add(userId);
                        else _selectedUserIds.remove(userId);
                      });
                    },
                    cells: [
                      DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(userData['displayName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(userData['email'] ?? 'N/A', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            ],
                          )
                      ),
                      DataCell(Text(userData['subscriptionTier']?.toUpperCase() ?? 'FREE')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Active'),
                        ),
                      ),
                      DataCell(Text(userData['downgradeReason'] ?? '')),
                      DataCell(Text(_formatPayment(userData['totalPaidAmount']))),
                      DataCell(_buildCopyableCell(userData['activeSession']?['deviceId'])),
                      DataCell(_buildCopyableCell(userData['exnessClientUid'])),
                      DataCell(Text(userData['exnessClientAccount']?.toString() ?? 'N/A')),
                      DataCell(Text(createdAt != null ? DateFormat('dd/MM/yy').format(createdAt.toDate()) : 'N/A')),
                      DataCell(Text(expiryDate != null ? DateFormat('dd/MM/yy').format(expiryDate.toDate()) : 'N/A')),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _handleDowngradeUsers,
        label: const Text('Hạ cấp về Free'),
        icon: const Icon(Icons.arrow_downward),
        backgroundColor: Colors.orange.shade800,
      )
          : null,
    );
  }

  Widget _buildCopyableCell(String? text) {
    if (text == null || text.isEmpty) {
      return const Text('N/A');
    }
    return Row(
      children: [
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép!'), duration: Duration(seconds: 1)));
          },
          child: const Icon(Icons.copy, size: 14, color: Colors.blueAccent),
        ),
      ],
    );
  }
}
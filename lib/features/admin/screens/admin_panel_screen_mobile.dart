// lib/features/admin/screens/admin_panel_screen_mobile.dart

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

  // Hàm xử lý nghiệp vụ "Hạ cấp"
  void _handleDowngradeUsers() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất một tài khoản.')));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hạ cấp tài khoản về Free'),
        content: TextField(
          controller: _reasonController,
          decoration: const InputDecoration(hintText: 'Nhập lý do hạ cấp (bắt buộc)...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lý do không được để trống.')));
                return;
              }
              Navigator.of(context).pop();
              _executeDowngradeAction(reason: reason);
            },
            child: const Text('Xác nhận hạ cấp'),
          ),
        ],
      ),
    );
  }

  // Hàm thực thi hành động hạ cấp
  Future<void> _executeDowngradeAction({required String reason}) async {
    final message = await _adminService.downgradeUsersToFree(
      userIds: _selectedUserIds.toList(),
      reason: reason,
    );
    setState(() => _selectedUserIds.clear());
    _reasonController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Hàm helper định dạng tiền tệ
  String _formatPayment(dynamic amount) {
    if (amount == null || amount is! num) {
      return 'N/A';
    }
    // Quy tắc: Nếu số tiền > 2000, coi là VNĐ. Ngược lại là USD.
    if (amount > 2000) {
      final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ', decimalDigits: 0);
      return format.format(amount);
    } else {
      final format = NumberFormat.currency(locale: 'en_US', symbol: '\$');
      return format.format(amount);
    }
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
        title: const Text('Bảng quản lý Admin'),
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
          final users = snapshot.data!.docs;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final userId = userDoc.id;
              final isSelected = _selectedUserIds.contains(userId);

              return Container(
                color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                child: ExpansionTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) _selectedUserIds.add(userId);
                        else _selectedUserIds.remove(userId);
                      });
                    },
                  ),
                  title: _buildUserTitle(userData),
                  subtitle: Text(userData['email'] ?? 'N/A'),
                  children: [_buildUserDetails(userData)],
                ),
              );
            },
          );
        },
      ),
      // Chỉ còn duy nhất nút "Hạ cấp về Free"
      bottomNavigationBar: _selectedUserIds.isNotEmpty
          ? BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _handleDowngradeUsers,
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Hạ cấp về Free'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildUserTitle(Map<String, dynamic> userData) {
    final displayName = userData['displayName'] ?? 'N/A';
    final role = userData['role'] ?? 'user';
    return Text(
      displayName,
      style: TextStyle(
        color: role == 'admin' ? Colors.amber : null,
        fontWeight: role == 'admin' ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildUserDetails(Map<String, dynamic> userData) {
    final Timestamp? createdAt = userData['createdAt'];
    final Timestamp? expiryDate = userData['subscriptionExpiryDate'];
    final createdDateString = createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate()) : 'N/A';
    final expiryDateString = expiryDate != null ? DateFormat('dd/MM/yyyy').format(expiryDate.toDate()) : 'N/A';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: Colors.black.withOpacity(0.1),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildDetailRow(Icons.badge_outlined, 'Group:', userData['subscriptionTier']?.toUpperCase() ?? 'FREE'),
          _buildDetailRow(Icons.phone_android, 'Mobile UID:', userData['activeSession']?['deviceId'] ?? 'N/A', canCopy: true),
          _buildDetailRow(Icons.person_pin_outlined, 'Exness Client UID:', userData['exnessClientUid'] ?? 'N/A', canCopy: true),
          _buildDetailRow(Icons.account_balance_wallet_outlined, 'Exness Account:', userData['exnessClientAccount']?.toString() ?? 'N/A'),
          // SỬ DỤNG HÀM ĐỊNH DẠNG TIỀN TỆ
          _buildDetailRow(Icons.payment, 'Payment:', _formatPayment(userData['totalPaidAmount'])),
          _buildDetailRow(Icons.date_range, 'Ngày tạo:', createdDateString),
          _buildDetailRow(Icons.timer_off_outlined, 'Ngày hết hạn:', expiryDateString),
          if(userData['downgradeReason'] != null && (userData['downgradeReason'] as String).isNotEmpty)
            _buildDetailRow(Icons.info_outline, 'Lý do hạ cấp:', userData['downgradeReason']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value, {bool canCopy = false}) {
    // ... không đổi ...
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          if (canCopy && value != 'N/A')
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép!'), duration: Duration(seconds: 1)));
              },
              child: const Icon(Icons.copy, size: 14, color: Colors.blueAccent),
            )
        ],
      ),
    );
  }
}
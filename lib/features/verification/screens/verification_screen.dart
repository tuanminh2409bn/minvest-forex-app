import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:provider/provider.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  File? _imageFile;
  bool _isLoading = false;
  String _statusMessage = 'Vui lòng tải lên ảnh chụp màn hình tài khoản Exness của bạn để được phân quyền.';

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Thêm listener ngay khi màn hình được tạo
    // Dùng addPostFrameCallback để đảm bảo context đã sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).addListener(_handleVerificationResult);
      }
    });
  }

  @override
  void dispose() {
    // Hủy listener khi màn hình bị xóa khỏi cây widget để tránh memory leak
    Provider.of<UserProvider>(context, listen: false).removeListener(_handleVerificationResult);
    super.dispose();
  }

  // Hàm lắng nghe và xử lý kết quả từ UserProvider
  void _handleVerificationResult() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.verificationStatus == 'failed') {
      final errorMessage = userProvider.verificationError ?? 'An unknown error occurred.';

      // Dùng `mounted` để đảm bảo widget còn tồn tại
      if (mounted) {
        _showFeedbackSnackbar(errorMessage, isError: true);
        setState(() {
          _isLoading = false;
          _statusMessage = 'Xác thực thất bại. Vui lòng thử lại với ảnh khác.';
        });
      }
      userProvider.clearVerificationStatus();
    }
  }

  // Hàm hiển thị SnackBar
  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _statusMessage = 'Đã chọn ảnh. Nhấn "Gửi Đi" để xử lý.';
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || _currentUser == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tải và xử lý ảnh...';
    });

    try {
      final ref = _storage.ref().child('verification_images/${_currentUser!.uid}.jpg');
      await ref.putFile(_imageFile!);
      // Khi tải lên thành công, chúng ta chỉ cần chờ listener xử lý kết quả
      // Không cần thay đổi status message ở đây nữa

    } catch (e) {
      if (!mounted) return;
      // Nếu có lỗi ngay lúc tải lên (ví dụ: mất mạng)
      setState(() {
        _statusMessage = 'Tải ảnh lên thất bại. Vui lòng thử lại.';
      });
      _showFeedbackSnackbar('Tải ảnh lên thất bại. Vui lòng thử lại.', isError: true);
      print('Lỗi tải ảnh: $e');
    } finally {
      // =========== THÊM KHỐI LỆNH NÀY ===========
      // Khối finally sẽ LUÔN LUÔN được chạy sau khi try-catch kết thúc
      // Đảm bảo vòng xoay loading được tắt đi
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // ===========================================
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Thực Tài Khoản'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_imageFile != null) ...[
              Image.file(_imageFile!, height: 200),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Chọn ảnh từ thư viện'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_imageFile == null || _isLoading) ? null : _uploadImage,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Gửi Đi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
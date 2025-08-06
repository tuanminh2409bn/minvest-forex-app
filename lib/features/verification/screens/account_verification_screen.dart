import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:provider/provider.dart';

// Enum để quản lý các trạng thái của giao diện
enum VerificationState { initial, imageSelected, loading, success, failure }

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  State<AccountVerificationScreen> createState() => _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen> {
  File? _selectedImage;
  VerificationState _currentState = VerificationState.initial;
  String _errorMessage = '';
  String _successTier = '';

  // Hàm chọn ảnh từ thư viện
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _currentState = VerificationState.imageSelected;
      });
    }
  }

  // Hàm tải ảnh lên Firebase Storage
  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _currentState = VerificationState.loading;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('verification_images/$userId.jpg');

      await imageRef.putFile(_selectedImage!);
      // Sau khi upload xong, lắng nghe sự thay đổi từ provider
      _listenForVerificationResult();

    } catch (e) {
      setState(() {
        _currentState = VerificationState.failure;
        _errorMessage = "Failed to upload image. Please try again.";
      });
    }
  }

  // Hàm lắng nghe kết quả từ UserProvider
  void _listenForVerificationResult() {
    // Sử dụng Provider.of với listen: true trong một hàm riêng
    // để nó có thể rebuild khi provider thay đổi.
    // Tuy nhiên, cách tiếp cận tốt hơn là dùng Consumer hoặc Selector.
    // Ở đây, chúng ta sẽ đơn giản hóa bằng cách kiểm tra trong didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lắng nghe sự thay đổi của UserProvider
    final userProvider = Provider.of<UserProvider>(context);

    if (_currentState == VerificationState.loading) {
      if (userProvider.verificationStatus == 'success') {
        // Cập nhật trạng thái khi xác thực thành công
        if (mounted) {
          setState(() {
            _currentState = VerificationState.success;
            _successTier = userProvider.userTier ?? 'N/A';
          });
        }
      } else if (userProvider.verificationStatus == 'failed') {
        // Cập nhật trạng thái khi xác thực thất bại
        if (mounted) {
          setState(() {
            _currentState = VerificationState.failure;
            _errorMessage = userProvider.verificationError ?? 'Verification failed.';
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'ACCOUNT VERIFICATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color.fromARGB(255, 20, 29, 110)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case VerificationState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Processing your account...', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        );
      case VerificationState.success:
        return _buildSuccessView();
      case VerificationState.failure:
        return _buildFailureView();
      case VerificationState.initial:
      case VerificationState.imageSelected:
      default:
        return _buildInitialView();
    }
  }

  Widget _buildInitialView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImage == null
                  ? Image.asset('assets/images/exness_example.png', fit: BoxFit.contain)
                  : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Please upload a screenshot of your Exness account to be authorized (your account must be opened under Minvest\'s Exness link)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 30),
            _buildActionButton(
              text: 'Select photo from library',
              onPressed: _pickImage,
              isPrimary: false,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              text: 'Send',
              onPressed: _selectedImage != null ? _uploadImage : null,
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET SUCCESS VIEW ĐÃ ĐƯỢC SỬA LẠI ---
  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // Đảm bảo căn giữa theo chiều ngang
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        const Text(
          'ACCOUNT VERIFIED SUCCESSFULLY',
          textAlign: TextAlign.center, // Đảm bảo text nhiều dòng được căn giữa
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Your account is ${_successTier.toUpperCase()}',
          style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),

        // Thêm widget hiển thị quyền lợi
        _buildTierBenefitsCard(_successTier),

        const SizedBox(height: 40),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text(
            'Return to home page >',
            style: TextStyle(color: Colors.blueAccent, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // --- WIDGET MỚI: HIỂN THỊ QUYỀN LỢI CỦA TÀI KHOẢN ---
  Widget _buildTierBenefitsCard(String tier) {
    final Map<String, String> tierInfo = _getTierInfo(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildBenefitRow('Signal time:', tierInfo['signal_time']!),
          _buildBenefitRow('Lot/week:', tierInfo['lot_week']!),
          _buildBenefitRow('Signal Quantity:', tierInfo['signal_qty']!),
        ],
      ),
    );
  }

  // Widget con để hiển thị một dòng quyền lợi
  Widget _buildBenefitRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Hàm lấy thông tin quyền lợi (tái sử dụng)
  Map<String, String> _getTierInfo(String tier) {
    switch (tier.toLowerCase()) {
      case 'demo':
        return {
          'signal_time': '8h-17h',
          'lot_week': '0.05',
          'signal_qty': '7-8 per day',
        };
      case 'vip':
        return {
          'signal_time': '8h-17h',
          'lot_week': '0.3',
          'signal_qty': 'full',
        };
      case 'elite':
        return {
          'signal_time': 'fulltime',
          'lot_week': '0.5',
          'signal_qty': 'full',
        };
      default:
        return {
          'signal_time': 'N/A',
          'lot_week': 'N/A',
          'signal_qty': 'N/A',
        };
    }
  }


  Widget _buildFailureView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center, // Đảm bảo căn giữa
      children: [
        const Icon(Icons.error, color: Colors.red, size: 80),
        const SizedBox(height: 20),
        const Text('Upgrade failed!', style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
            _errorMessage,
            textAlign: TextAlign.center, // Đảm bảo căn giữa
            style: const TextStyle(color: Colors.white70)
        ),
        const SizedBox(height: 40),
        _buildActionButton(
          text: 'Re-upload the image',
          onPressed: () {
            setState(() {
              _selectedImage = null;
              _currentState = VerificationState.initial;
            });
          },
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({required String text, required VoidCallback? onPressed, required bool isPrimary}) {
    final bool isEnabled = onPressed != null;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: Colors.grey.withOpacity(0.2),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEnabled && isPrimary
                ? const LinearGradient(
              colors: [Color(0xFF172AFE), Color(0xFF3C4BFE), Color(0xFF5E69FD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: isEnabled && !isPrimary ? const Color(0xFF151a2e) : null,
            borderRadius: BorderRadius.circular(12),
            border: isEnabled && !isPrimary ? Border.all(color: Colors.blueAccent) : null,
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isEnabled ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

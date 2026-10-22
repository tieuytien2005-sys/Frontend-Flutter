import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/face_api_service.dart';
import '../../services/face_embedding_helper.dart';
import '../../services/role_router.dart';

class FaceScanScreen extends StatefulWidget {
  final bool isLogin;
  final String? username; // Cần thiết nếu là chế độ Đăng ký

  const FaceScanScreen({
    super.key,
    required this.isLogin,
    this.username,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final FaceEmbeddingHelper _embeddingHelper = FaceEmbeddingHelper();

  File? _capturedImage;
  bool _isProcessing = false;
  String _statusText = 'Vui lòng đưa khuôn mặt vào giữa khung tròn';

  @override
  void dispose() {
    _embeddingHelper.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (file == null) return;

      setState(() {
        _capturedImage = File(file.path);
        _isProcessing = true;
        _statusText = 'Đang phân tích khuôn mặt & trích xuất vector AI...';
      });

      // 1. Trích xuất vector 128 chiều On-Device
      final List<double> embedding = await _embeddingHelper.extractEmbedding(file.path);

      if (!mounted) return;

      // 2. Chuyển đổi ảnh sang Base64
      final bytes = await _capturedImage!.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (widget.isLogin) {
        // CHẾ ĐỘ ĐĂNG NHẬP (Nhận diện 1:N hoặc 1:1)
        setState(() => _statusText = 'Đang đối chiếu khuôn mặt với máy chủ...');
        final result = await FaceApiService.loginFace(
          embedding,
          username: widget.username,
          threshold: 0.70,
        );

        if (!mounted) return;
        setState(() => _isProcessing = false);

        if (result.isSuccess && result.data != null) {
          final role = result.data!.role;
          final user = result.data!.username ?? '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xác thực Face ID thành công! Chào $user'),
              backgroundColor: Colors.green,
            ),
          );

          // Điều hướng đúng vai trò
          RoleRouter.navigateByRole(context, role);
        } else {
          _showErrorDialog(result.errorMessage ?? 'Khuôn mặt không khớp với bất kỳ tài khoản nào.');
        }
      } else {
        // CHẾ ĐỘ ĐĂNG KÝ
        if (widget.username == null || widget.username!.isEmpty) {
          setState(() => _isProcessing = false);
          _showErrorDialog('Thiếu thông tin username để đăng ký.');
          return;
        }

        setState(() => _statusText = 'Đang lưu dữ liệu khuôn mặt lên máy chủ...');
        final result = await FaceApiService.registerFace(
          widget.username!,
          embedding,
          imageBase64: base64Image,
        );

        if (!mounted) return;
        setState(() => _isProcessing = false);

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.data ?? 'Đăng ký Face ID thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          _showErrorDialog(result.errorMessage ?? 'Đăng ký khuôn mặt thất bại.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Nhận diện thất bại', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _capturedImage = null;
                _statusText = 'Vui lòng thử lại với góc chụp rõ và đủ sáng';
              });
            },
            child: const Text('THỬ LẠI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isLogin ? 'Đăng Nhập Face ID' : 'Đăng Ký Face ID';
    final subtitle = widget.isLogin
        ? 'Hệ thống AI sẽ nhận diện khuôn mặt và đăng nhập tức thì'
        : 'Ghi nhận đặc trưng khuôn mặt cho tài khoản: ${widget.username ?? ""}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 30),

              // Khung tròn quét khuôn mặt
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Viền phát sáng tròn
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isProcessing ? Colors.amber : Colors.deepPurple,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isProcessing ? Colors.amber : Colors.deepPurple)
                                .withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),

                    // Ảnh xem trước hoặc Icon mặt người
                    ClipOval(
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: _capturedImage != null
                            ? Image.file(_capturedImage!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.deepPurple.shade50,
                                child: const Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 110,
                                  color: Colors.deepPurple,
                                ),
                              ),
                      ),
                    ),

                    // Hiệu ứng đang quét
                    if (_isProcessing)
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            SizedBox(height: 12),
                            Text(
                              'Đang xử lý AI...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Trạng thái hướng dẫn
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isProcessing ? Icons.sync : Icons.info_outline,
                      color: Colors.deepPurple,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Nút chụp ảnh từ Camera
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'CHỤP ẢNH TỪ CAMERA TRƯỚC',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nút chọn từ thư viện
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Colors.deepPurple),
                  ),
                  onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: Colors.deepPurple),
                  label: const Text(
                    'CHỌN ẢNH TỪ BỘ SƯU TẬP',
                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

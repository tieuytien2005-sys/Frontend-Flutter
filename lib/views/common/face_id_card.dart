import 'package:flutter/material.dart';
import '../../services/face_api_service.dart';
import '../../services/storage_service.dart';
import '../auth/face_scan_screen.dart';

class FaceIdManagementCard extends StatefulWidget {
  final String username;
  final Color primaryColor;

  const FaceIdManagementCard({
    super.key,
    required this.username,
    this.primaryColor = Colors.deepPurple,
  });

  @override
  State<FaceIdManagementCard> createState() => _FaceIdManagementCardState();
}

class _FaceIdManagementCardState extends State<FaceIdManagementCard> {
  bool _isLoading = true;
  bool _hasFace = false;

  @override
  void initState() {
    super.initState();
    _checkFaceStatus();
  }

  @override
  void didUpdateWidget(covariant FaceIdManagementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _checkFaceStatus();
    }
  }

  Future<void> _checkFaceStatus() async {
    if (widget.username.isEmpty) return;

    // Nạp trạng thái từ cache tức thì
    final cached = await StorageService.isFaceRegistered(widget.username);
    if (mounted) {
      setState(() {
        _hasFace = cached;
      });
    }

    setState(() => _isLoading = true);

    final result = await FaceApiService.getFaceStatus(widget.username);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess && result.data != null) {
        _hasFace = result.data!.hasFace;
      }
    });
  }

  Future<void> _handleRegisterFace() async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FaceScanScreen(
          isLogin: false,
          username: widget.username,
        ),
      ),
    );

    if (success == true) {
      await StorageService.setFaceRegistered(widget.username, true);
      if (mounted) setState(() => _hasFace = true);
      _checkFaceStatus();
    }
  }

  Future<void> _handleRemoveFace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận gỡ bỏ'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa dữ liệu khuôn mặt đã lưu? Bạn sẽ không thể đăng nhập nhanh bằng Face ID nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('GỠ BỎ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final result = await FaceApiService.removeFace(widget.username);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      await StorageService.setFaceRegistered(widget.username, false);
      if (!mounted) return;
      setState(() => _hasFace = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gỡ bỏ Face ID thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _checkFaceStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gỡ bỏ Face ID thất bại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.primaryColor.withValues(alpha: 0.15),
                  radius: 22,
                  child: Icon(
                    Icons.face_retouching_natural_rounded,
                    color: widget.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xác thực Khuôn mặt (Face ID)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      if (_isLoading)
                        const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hasFace ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hasFace ? 'Đã kích hoạt' : 'Chưa kích hoạt',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _hasFace ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Kiểm tra trạng thái',
                  onPressed: _checkFaceStatus,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _hasFace
                  ? 'Khuôn mặt của bạn đã được ghi nhận. Bạn có thể sử dụng Face ID để đăng nhập nhanh không cần mật khẩu.'
                  : 'Hãy đăng ký khuôn mặt để đăng nhập an toàn, tiện lợi trong 1 chạm.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
            ),
            const SizedBox(height: 16),
            if (_hasFace)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleRemoveFace,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Gỡ bỏ Face ID'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleRegisterFace,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Chụp lại'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _handleRegisterFace,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'ĐĂNG KÝ FACE ID NGAY',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

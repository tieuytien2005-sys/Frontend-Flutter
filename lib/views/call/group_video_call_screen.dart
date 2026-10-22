import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/call_models.dart';
import '../../services/call_service.dart';
import '../../services/storage_service.dart';

class GroupVideoCallScreen extends StatefulWidget {
  final String roomCode;
  final String roomTitle;
  final String hostUserId;
  final String? hostName;

  const GroupVideoCallScreen({
    super.key,
    required this.roomCode,
    required this.roomTitle,
    required this.hostUserId,
    this.hostName,
  });

  @override
  State<GroupVideoCallScreen> createState() => _GroupVideoCallScreenState();
}

class _GroupVideoCallScreenState extends State<GroupVideoCallScreen> {
  // Camera state
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _hasCameraError = false;
  String? _cameraErrorMessage;

  // Media toggles
  bool _isMuted = false;
  bool _isCameraOff = false;

  // Room details & Call state
  CallRoomModel? _roomDetails;
  String _currentUsername = '';
  String _currentUserRole = '';
  bool _isHostOrAdmin = false;

  // Timers
  Timer? _callDurationTimer;
  int _callSeconds = 0;
  Timer? _statusPollTimer;
  bool _isEndingCall = false;

  @override
  void initState() {
    super.initState();
    _initUserAndMedia();
  }

  Future<void> _initUserAndMedia() async {
    // 1. Lấy thông tin tài khoản hiện tại
    _currentUsername = await StorageService.getUsername() ?? 'Thành viên';
    _currentUserRole = await StorageService.getRole() ?? '';

    if (!mounted) return;

    // 2. Tải chi tiết phòng gọi từ Backend
    await _fetchRoomDetails();

    // 3. Khởi tạo Camera an toàn (Bắt buộc bọc trong try/catch chống crash máy ảo)
    await _initCameraSafe();

    // 4. Bắt đầu đếm thời gian cuộc gọi
    _startCallTimer();

    // 5. Bắt đầu định kỳ kiểm tra trạng thái phòng (Polling mỗi 3 giây)
    _startStatusPolling();
  }

  /// LƯU Ý KỸ THUẬT 1: Khởi tạo Camera An toàn với cơ chế Fallback Avatar cho Máy Ảo
  Future<void> _initCameraSafe() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _hasCameraError = true;
          _cameraErrorMessage = 'Không tìm thấy thiết bị camera phần cứng.';
          _isCameraOff = true;
        });
        return;
      }

      // Ưu tiên chọn camera trước (Front camera) cho gọi video
      _selectedCameraIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      final camera = _availableCameras[_selectedCameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _hasCameraError = false;
      });
    } on CameraException catch (e) {
      // Bắt riêng lỗi CameraException khi chạy trên Emulator không có webcam
      if (!mounted) return;
      setState(() {
        _hasCameraError = true;
        _cameraErrorMessage = 'Máy ảo chưa bật Webcam hoặc bị chặn quyền (${e.description ?? e.code})';
        _isCameraOff = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasCameraError = true;
        _cameraErrorMessage = 'Không thể khởi động camera: $e';
        _isCameraOff = true;
      });
    }
  }

  /// Chuyển đổi camera trước/sau
  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2 || _isCameraOff) return;

    final nextIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _cameraController?.dispose();

    _selectedCameraIndex = nextIndex;
    final nextCamera = _availableCameras[_selectedCameraIndex];

    try {
      _cameraController = CameraController(
        nextCamera,
        ResolutionPreset.medium,
        enableAudio: !_isMuted,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (_) {}
  }

  /// Lấy chi tiết phòng và danh sách người tham gia
  Future<void> _fetchRoomDetails() async {
    final res = await CallService.getRoomDetails(widget.roomCode);
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final room = res.data!;
      final isAdmin = _currentUserRole.toLowerCase() == 'admin';
      final isHost = (room.hostName != null && room.hostName!.toLowerCase() == _currentUsername.toLowerCase()) ||
          (widget.hostName != null && widget.hostName!.toLowerCase() == _currentUsername.toLowerCase());

      setState(() {
        _roomDetails = room;
        _isHostOrAdmin = isAdmin || isHost;
      });

      // Kiểm tra ngay nếu phòng đã bị đóng trước đó
      if (room.isEnded) {
        _handleRoomEndedByHost();
      }
    }
  }

  /// LƯU Ý KỸ THUẬT 2: Định kỳ kiểm tra trạng thái phòng (Polling 3s)
  /// Tự động đóng phòng khi Chủ phòng hoặc Admin bấm kết thúc
  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _isEndingCall) return;

      final res = await CallService.getRoomDetails(widget.roomCode);
      if (!mounted) return;

      if (res.isSuccess && res.data != null) {
        final room = res.data!;
        setState(() => _roomDetails = room);

        if (room.isEnded) {
          _statusPollTimer?.cancel();
          _handleRoomEndedByHost();
        }
      }
    });
  }

  /// Xử lý sự kiện phòng bị đóng bởi Chủ phòng
  void _handleRoomEndedByHost() {
    if (!mounted) return;
    _statusPollTimer?.cancel();
    _callDurationTimer?.cancel();

    // Đóng màn hình gọi video
    Navigator.of(context).pop();

    // Hiển thị thông báo xác nhận
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.call_end, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cuộc gọi đã được kết thúc bởi chủ phòng/quản trị viên.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCallTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callSeconds++);
    });
  }

  String _formatCallDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// LƯU Ý KỸ THUẬT 3: Tiện ích sao chép mã phòng vào Clipboard
  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Đã sao chép mã phòng: ${widget.roomCode}'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Kết thúc phòng gọi nhóm (Dành cho Chủ phòng hoặc Admin)
  Future<void> _confirmEndCall() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Kết thúc cuộc gọi nhóm?'),
          ],
        ),
        content: const Text(
          'Toàn bộ thành viên sẽ tự động rời khỏi phòng. Thao tác này chỉ dành cho Chủ phòng hoặc Quản trị viên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kết thúc ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isEndingCall = true);

      final res = await CallService.endRoom(widget.roomCode);

      if (!mounted) return;
      setState(() => _isEndingCall = false);

      if (res.isSuccess) {
        _statusPollTimer?.cancel();
        _callDurationTimer?.cancel();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đóng phòng gọi video nhóm thành công.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Không thể kết thúc phòng'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Rời khỏi phòng gọi (Dành cho thành viên bình thường)
  void _leaveCall() {
    _statusPollTimer?.cancel();
    _callDurationTimer?.cancel();
    Navigator.of(context).pop();
  }

  /// LƯU Ý KỸ THUẬT 1: Giải phóng phần cứng Camera an toàn trong dispose()
  @override
  void dispose() {
    _callDurationTimer?.cancel();
    _statusPollTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Nền tối hiện đại sang trọng
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP BAR: Tiêu đề, Mã phòng kèm Icon Copy, Thời lượng gọi
            _buildTopBar(),

            // 2. KHÔNG GIAN VIDEO GRID (Camera chính và các thành viên)
            Expanded(
              child: _buildVideoGrid(),
            ),

            // 3. BOTTOM CONTROL BAR: Mute, Camera, Flip, Leave, End Call
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  /// Widget Top Bar với tiện ích Clipboard UX
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withValues(alpha: 0.6),
      child: Row(
        children: [
          // Nút back / leave
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _leaveCall,
          ),

          // Tiêu đề & Host
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.roomTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Thời lượng: ${_formatCallDuration(_callSeconds)}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
          ),

          // LƯU Ý 3: Tiện ích Sao Chép Mã Phòng (Clipboard UX)
          InkWell(
            onTap: _copyRoomCode,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.meeting_room, size: 16, color: Colors.amberAccent),
                  const SizedBox(width: 4),
                  Text(
                    widget.roomCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Nút mở danh sách thành viên
          IconButton(
            icon: Badge(
              label: Text('${(_roomDetails?.participants.length ?? 0) + 1}'),
              child: const Icon(Icons.people_outline, color: Colors.white),
            ),
            tooltip: 'Danh sách thành viên',
            onPressed: _showParticipantsSheet,
          ),
        ],
      ),
    );
  }

  /// Lưới Video hiển thị Video của tôi (Local Preview) và các thành viên khác
  Widget _buildVideoGrid() {
    final otherParticipants = _roomDetails?.participants ?? [];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Khung Video của chính tôi
          Expanded(
            flex: otherParticipants.isEmpty ? 1 : 1,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // LƯU Ý 1: Nếu Camera khởi tạo thành công & không tắt camera -> Hiện CameraPreview
                  if (_isCameraInitialized && !_isCameraOff && !_hasCameraError && _cameraController != null)
                    CameraPreview(_cameraController!)
                  // Fallback: Hiện Avatar + Tên với nền tối sang trọng khi chạy trên Emulator / tắt cam
                  else
                    _buildAvatarFallback(
                      name: _currentUsername,
                      subtitle: _hasCameraError
                          ? (_cameraErrorMessage ?? 'Mô phỏng Máy ảo (Avatar Fallback)')
                          : (_isCameraOff ? 'Camera đang tắt' : 'Đang tải camera...'),
                      avatarColor: Colors.blue.shade700,
                    ),

                  // Tag Tên người dùng & Trạng thái Mic
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isMuted ? Icons.mic_off : Icons.mic,
                            color: _isMuted ? Colors.redAccent : Colors.greenAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_currentUsername (Tôi)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tag Chủ phòng nếu là Host
                  if (_isHostOrAdmin)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Chủ phòng',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Các ô của các thành viên khác trong phòng (nếu có)
          if (otherParticipants.isNotEmpty)
            Expanded(
              flex: 1,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: otherParticipants.length,
                itemBuilder: (ctx, idx) {
                  final p = otherParticipants[idx];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF232336),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildAvatarFallback(
                          name: p.fullName.isNotEmpty ? p.fullName : p.username,
                          subtitle: p.isCameraOff ? 'Camera tắt' : 'Đang kết nối...',
                          avatarColor: Colors.deepPurple.shade700,
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.isMuted ? Icons.mic_off : Icons.mic,
                                  color: p.isMuted ? Colors.redAccent : Colors.greenAccent,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  p.fullName.isNotEmpty ? p.fullName : p.username,
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// LƯU Ý 1: Avatar Fallback với nền tối sang trọng khi không có Camera
  Widget _buildAvatarFallback({
    required String name,
    required String subtitle,
    required Color avatarColor,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thanh điều khiển bên dưới (Bottom Control Bar)
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Nút Bật/Tắt Mic
          _buildActionButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Bật Mic' : 'Tắt Mic',
            color: _isMuted ? Colors.redAccent : Colors.white24,
            iconColor: Colors.white,
            onTap: () {
              setState(() => _isMuted = !_isMuted);
            },
          ),

          // Nút Bật/Tắt Camera
          _buildActionButton(
            icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
            label: _isCameraOff ? 'Bật Cam' : 'Tắt Cam',
            color: _isCameraOff ? Colors.redAccent : Colors.white24,
            iconColor: Colors.white,
            onTap: () {
              setState(() => _isCameraOff = !_isCameraOff);
            },
          ),

          // Nút Lật Camera
          _buildActionButton(
            icon: Icons.flip_camera_ios,
            label: 'Đổi Cam',
            color: Colors.white24,
            iconColor: Colors.white,
            onTap: _flipCamera,
          ),

          // Nút Rời phòng (Leave Call)
          _buildActionButton(
            icon: Icons.call_end,
            label: 'Rời phòng',
            color: Colors.orange.shade800,
            iconColor: Colors.white,
            onTap: _leaveCall,
          ),

          // Nút KẾT THÚC PHÒNG (Chỉ hiển thị hoặc cho phép khi là Chủ phòng hoặc Admin)
          if (_isHostOrAdmin)
            _buildActionButton(
              icon: Icons.power_settings_new,
              label: 'Đóng phòng',
              color: Colors.red.shade700,
              iconColor: Colors.white,
              onTap: _confirmEndCall,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  void _showParticipantsSheet() {
    final participants = _roomDetails?.participants ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thành viên trong phòng (${participants.length + 1})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text('$_currentUsername (Tôi)', style: const TextStyle(color: Colors.white)),
              subtitle: Text(_isHostOrAdmin ? 'Chủ phòng' : 'Thành viên', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              trailing: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? Colors.redAccent : Colors.greenAccent,
                size: 18,
              ),
            ),
            ...participants.map((p) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade700,
                  child: Text(
                    p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : p.username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  p.fullName.isNotEmpty ? p.fullName : p.username,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: const Text('Thành viên', style: TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: Icon(
                  p.isMuted ? Icons.mic_off : Icons.mic,
                  color: p.isMuted ? Colors.redAccent : Colors.greenAccent,
                  size: 18,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
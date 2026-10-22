import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/call_models.dart';
import '../../services/call_service.dart';
import '../../services/storage_service.dart';
import 'group_video_call_screen.dart';

class CallHomeScreen extends StatefulWidget {
  const CallHomeScreen({super.key});

  @override
  State<CallHomeScreen> createState() => _CallHomeScreenState();
}

class _CallHomeScreenState extends State<CallHomeScreen> {
  final TextEditingController _joinCodeController = TextEditingController();
  bool _isLoadingHistory = true;
  bool _isCreatingRoom = false;
  bool _isJoining = false;
  List<CallRoomModel> _history = [];
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndHistory();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfoAndHistory() async {
    _currentUsername = await StorageService.getUsername() ?? '';
    if (!mounted) return;
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);

    final list = await CallService.getCallHistory();

    if (!mounted) return;
    setState(() {
      _history = list;
      _isLoadingHistory = false;
    });
  }

  /// Tham gia phòng gọi bằng mã phòng 6 chữ số
  Future<void> _joinRoom(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã phòng gọi')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isJoining = true);

    final res = await CallService.getRoomDetails(cleanCode);

    if (!mounted) return;
    setState(() => _isJoining = false);

    if (res.isSuccess && res.data != null) {
      final room = res.data!;
      if (room.isEnded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phòng gọi này đã kết thúc.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Mở màn hình gọi video nhóm
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupVideoCallScreen(
            roomCode: room.roomCode,
            roomTitle: room.title,
            hostUserId: room.hostUserId,
            hostName: room.hostName,
          ),
        ),
      );

      // Tải lại lịch sử khi quay về
      _loadHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Không tìm thấy phòng gọi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Hiển thị Dialog tạo phòng gọi mới
  void _showCreateRoomDialog() {
    final titleController = TextEditingController(text: 'Cuộc họp nhóm $_currentUsername');
    int selectedMax = 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.video_call, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Tạo phòng gọi nhóm mới'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tiêu đề cuộc họp:'),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Nhập tiêu đề...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Số lượng người tối đa:'),
                  DropdownButton<int>(
                    value: selectedMax,
                    items: const [
                      DropdownMenuItem(value: 4, child: Text('4 người')),
                      DropdownMenuItem(value: 10, child: Text('10 người')),
                      DropdownMenuItem(value: 20, child: Text('20 người')),
                      DropdownMenuItem(value: 50, child: Text('50 người')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMax = val);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(ctx);
                await _performCreateRoom(title, selectedMax);
              },
              child: const Text('Tạo & Vào phòng', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performCreateRoom(String title, int maxParticipants) async {
    if (!mounted) return;
    setState(() => _isCreatingRoom = true);

    final res = await CallService.createRoom(
      title: title,
      maxParticipants: maxParticipants,
    );

    if (!mounted) return;
    setState(() => _isCreatingRoom = false);

    if (res.isSuccess && res.data != null) {
      final room = res.data!;
      // Mở ngay màn hình gọi video nhóm
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupVideoCallScreen(
            roomCode: room.roomCode,
            roomTitle: room.title,
            hostUserId: room.hostUserId,
            hostName: room.hostName,
          ),
        ),
      );

      _loadHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Tạo phòng thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép mã phòng: $code'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuộc Gọi Video Nhóm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _isLoadingHistory ? null : _loadHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. BANNER HÀNH ĐỘNG CHÍNH (Tạo phòng & Tham gia phòng)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Nút Tạo phòng
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isCreatingRoom
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.add_call, color: Colors.white),
                        label: const Text(
                          'Tạo phòng gọi nhóm mới',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isCreatingRoom ? null : _showCreateRoomDialog,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('HOẶC', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nhập mã phòng để vào
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _joinCodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Nhập mã phòng 6 số...',
                              prefixIcon: const Icon(Icons.pin),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isJoining ? null : () => _joinRoom(_joinCodeController.text),
                          child: _isJoining
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Vào', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. DANH SÁCH LỊCH SỬ CUỘC GỌI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử cuộc gọi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_history.length} cuộc gọi',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingHistory)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_history.isEmpty)
              _buildEmptyHistory()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                itemBuilder: (ctx, idx) {
                  final room = _history[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1.5,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: room.isActive
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        child: Icon(
                          room.isActive ? Icons.video_call : Icons.phone_disabled,
                          color: room.isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text(
                        room.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('Mã: ${room.roomCode}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _copyToClipboard(room.roomCode),
                                child: const Icon(Icons.copy, size: 14, color: Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chủ phòng: ${room.hostName ?? "N/A"}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(room.createdAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: room.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          room.isActive ? 'Đang gọi' : 'Đã kết thúc',
                          style: TextStyle(
                            color: room.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        if (room.isActive) {
                          _joinRoom(room.roomCode);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cuộc gọi này đã kết thúc trước đó.')),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.video_chat_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Chưa có lịch sử cuộc gọi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Hãy tạo phòng mới hoặc nhập mã để bắt đầu cuộc họp video nhóm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${local.year}';
  }
}
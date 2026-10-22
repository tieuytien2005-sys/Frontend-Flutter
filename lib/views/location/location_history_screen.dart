import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/location_models.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';

class LocationHistoryScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userRole;

  const LocationHistoryScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userRole,
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  List<LocationHistoryModel> _history = [];
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _checkIsMeAndLoad();
  }

  Future<void> _checkIsMeAndLoad() async {
    final currentUsername = await StorageService.getUsername();
    if (!mounted) return;
    setState(() {
      _isMe = (currentUsername != null && currentUsername.toLowerCase() == widget.userName.toLowerCase());
    });
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final list = await LocationService.getLocationHistory(widget.userId, limit: 100);

    if (!mounted) return;
    setState(() {
      _history = list;
      _isLoading = false;
    });

    if (_history.isNotEmpty) {
      final latest = _history.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(LatLng(latest.latitude, latest.longitude), 14.5);
      });
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xoá lịch sử vị trí?'),
          ],
        ),
        content: const Text(
          'Toàn bộ toạ độ di chuyển đã lưu trên hệ thống sẽ bị xoá vĩnh viễn. Bạn có chắc chắn muốn xoá?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final res = await LocationService.clearMyHistory();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xoá toàn bộ lịch sử vị trí thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Xoá lịch sử thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints = _history
        .map((e) => LatLng(e.latitude, e.longitude))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch sử: ${widget.userName}'),
            if (widget.userRole != null)
              Text(
                'Vai trò: ${widget.userRole}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (_isMe)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Xoá lịch sử vị trí của tôi',
              onPressed: _isLoading ? null : _confirmClearHistory,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _isLoading ? null : _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Bản đồ thu nhỏ hiển thị Polyline hành trình
                    Expanded(
                      flex: 4,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(
                            _history.first.latitude,
                            _history.first.longitude,
                          ),
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.nguyennhatthanhandr',
                          ),
                          if (polylinePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: polylinePoints,
                                  strokeWidth: 4.0,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: _history.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final isLatest = index == 0;
                              return Marker(
                                point: LatLng(item.latitude, item.longitude),
                                width: 36,
                                height: 36,
                                child: Icon(
                                  isLatest ? Icons.location_pin : Icons.circle,
                                  size: isLatest ? 36 : 14,
                                  color: isLatest ? Colors.redAccent : Colors.blue.shade700,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // Danh sách các mốc thời gian di chuyển
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Hành trình (${_history.length} mốc ghi nhận)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Mới nhất lên đầu',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _history.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final item = _history[idx];
                                  final isLatest = idx == 0;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: isLatest
                                          ? Colors.redAccent.withValues(alpha: 0.15)
                                          : Colors.blue.shade50,
                                      child: Icon(
                                        isLatest ? Icons.my_location : Icons.navigation_outlined,
                                        color: isLatest ? Colors.redAccent : Colors.blue,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      item.address ?? 'Toạ độ: ${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${_formatDateTime(item.recordedAt)}${item.speed != null ? " • Tốc độ: ${(item.speed! * 3.6).toStringAsFixed(1)} km/h" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                    onTap: () {
                                      if (!mounted) return;
                                      _mapController.move(
                                        LatLng(item.latitude, item.longitude),
                                        16.0,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Chưa có dữ liệu lịch sử vị trí',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Người dùng này chưa cập nhật vị trí nào trên hệ thống.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${local.year}';
  }
}

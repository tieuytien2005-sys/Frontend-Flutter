import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/location_models.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import 'location_history_screen.dart';

class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  final MapController _mapController = MapController();

  bool _isSharing = false;
  bool _isLoading = true;
  bool _isUpdatingLocation = false;

  // Vị trí của người dùng hiện tại
  double _myLat = LocationService.defaultLatitude;
  double _myLng = LocationService.defaultLongitude;
  String _myAddress = LocationService.defaultAddress;

  // Danh sách người dùng lân cận đang bật chia sẻ
  List<UserLocationModel> _activeUsers = [];

  // Bộ lọc
  double _selectedRadius = 15.0; // km
  String _selectedRole = 'All'; // All, Staff, Customer, Admin
  final List<String> _roleFilters = ['All', 'Staff', 'Customer', 'Admin'];

  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    _currentUsername = await StorageService.getUsername();
    if (!mounted) return;
    await _refreshCurrentPositionAndData();
  }

  /// Lấy vị trí GPS an toàn (Timeout 5s + Fallback TP.HCM) và tải danh sách lân cận
  Future<void> _refreshCurrentPositionAndData() async {
    if (!mounted) return;
    setState(() => _isUpdatingLocation = true);

    // 1. Lấy vị trí thiết bị an toàn
    final pos = await LocationService.getCurrentPositionSafe(
      onNotice: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _myLat = pos.latitude;
      _myLng = pos.longitude;
      _myAddress = pos.isFallback
          ? 'TP. Hồ Chí Minh (Mô phỏng/Fallback)'
          : 'Tọa độ GPS thiết bị (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
    });

    // 2. Tự động gửi cập nhật vị trí lên server
    await LocationService.updateLocation(
      latitude: _myLat,
      longitude: _myLng,
      address: _myAddress,
      speed: pos.speed,
    );

    // 3. Tải danh sách người dùng đang active xung quanh
    await _loadActiveUsers();

    if (!mounted) return;
    setState(() => _isUpdatingLocation = false);

    // Di chuyển camera về toạ độ hiện tại an toàn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(_myLat, _myLng), 14.5);
    });
  }

  /// Tải danh sách người dùng đang bật chia sẻ vị trí
  Future<void> _loadActiveUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final users = await LocationService.getActiveSharingUsers(
      latitude: _myLat,
      longitude: _myLng,
      radiusInKm: _selectedRadius,
      role: _selectedRole,
    );

    if (!mounted) return;
    // Kiểm tra trạng thái chia sẻ của bản thân từ danh sách server trả về
    final meInList = users.where((u) => u.username.toLowerCase() == _currentUsername?.toLowerCase()).firstOrNull;
    if (meInList != null) {
      _isSharing = meInList.isSharingLocation;
    }

    setState(() {
      _activeUsers = users;
      _isLoading = false;
    });
  }

  /// Bật/Tắt chia sẻ vị trí
  Future<void> _toggleSharing(bool value) async {
    if (!mounted) return;
    setState(() => _isSharing = value);

    final res = await LocationService.toggleSharing(value);
    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
              ? 'Đã BẬT chia sẻ vị trí. Các thành viên khác có thể thấy bạn trên bản đồ.'
              : 'Đã TẮT chia sẻ vị trí.',
          ),
          backgroundColor: value ? Colors.green : Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Tải lại danh sách sau khi thay đổi trạng thái
      await _loadActiveUsers();
    } else {
      setState(() => _isSharing = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Không thể đổi trạng thái chia sẻ'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Di chuyển bản đồ đến toạ độ chỉ định một cách an toàn
  void _safeMoveMap(double lat, double lng, {double zoom = 15.5}) {
    // Tuân thủ bắt buộc: Quản lý an toàn vòng đời Bản đồ
    if (!mounted) return;
    _mapController.move(LatLng(lat, lng), zoom);
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple.shade700;
      case 'staff':
        return Colors.teal.shade700;
      case 'customer':
      default:
        return Colors.indigo.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myLatLng = LatLng(_myLat, _myLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ Vị trí Real-time'),
        elevation: 1,
        actions: [
          IconButton(
            icon: _isUpdatingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Cập nhật toạ độ GPS của tôi',
            onPressed: _isUpdatingLocation ? null : _refreshCurrentPositionAndData,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại danh sách xung quanh',
            onPressed: _isLoading ? null : _loadActiveUsers,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. BẢN ĐỒ TƯƠNG TÁC (OpenStreetMap qua flutter_map)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: myLatLng,
              initialZoom: 14.5,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nguyennhatthanhandr',
              ),

              // Vòng tròn thể hiện bán kính tìm kiếm quanh vị trí hiện tại
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: myLatLng,
                    radius: _selectedRadius * 1000, // mét
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderColor: Colors.blue.withValues(alpha: 0.4),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // Markers
              MarkerLayer(
                markers: [
                  // Marker của chính tôi
                  Marker(
                    point: myLatLng,
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => _showMyInfoBottomSheet(),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6),
                              ],
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Tôi',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Markers của các user khác đang active
                  ..._activeUsers
                      .where((u) => u.latitude != null && u.longitude != null && u.username.toLowerCase() != _currentUsername?.toLowerCase())
                      .map((user) {
                    final color = _getRoleColor(user.role);
                    return Marker(
                      point: LatLng(user.latitude!, user.longitude!),
                      width: 54,
                      height: 54,
                      child: GestureDetector(
                        onTap: () => _showUserDetailModal(user),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 4),
                                ],
                              ),
                              child: const Icon(Icons.navigation, color: Colors.white, size: 18),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                user.fullName.isNotEmpty ? user.fullName.split(' ').last : user.username,
                                style: const TextStyle(color: Colors.white, fontSize: 9),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. THANH ĐIỀU KHIỂN TRÊN CÙNG (Card Toggle Chia sẻ & Bộ lọc)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Switch Chia sẻ vị trí
                    Row(
                      children: [
                        Icon(
                          _isSharing ? Icons.location_on : Icons.location_off,
                          color: _isSharing ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isSharing ? 'Đang chia sẻ vị trí' : 'Đang ẩn vị trí',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                _isSharing
                                    ? 'Người dùng khác có thể thấy bạn'
                                    : 'Bật để đồng đội hoặc khách tìm thấy bạn',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isSharing,
                          activeThumbColor: Colors.green,
                          onChanged: _toggleSharing,
                        ),
                      ],
                    ),

                    const Divider(height: 12),

                    // Bộ lọc bán kính & vai trò
                    Row(
                      children: [
                        // Lọc Role
                        Expanded(
                          flex: 5,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              value: _selectedRole,
                              items: _roleFilters.map((r) {
                                return DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r == 'All' ? 'Tất cả vai trò' : r,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _selectedRole) {
                                  setState(() => _selectedRole = val);
                                  _loadActiveUsers();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Lọc Bán kính
                        Expanded(
                          flex: 5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.radar, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '${_selectedRadius.toInt()} km',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              PopupMenuButton<double>(
                                icon: const Icon(Icons.arrow_drop_down),
                                initialValue: _selectedRadius,
                                onSelected: (val) {
                                  setState(() => _selectedRadius = val);
                                  _loadActiveUsers();
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(value: 5.0, child: Text('Bán kính 5 km')),
                                  PopupMenuItem(value: 10.0, child: Text('Bán kính 10 km')),
                                  PopupMenuItem(value: 20.0, child: Text('Bán kính 20 km')),
                                  PopupMenuItem(value: 50.0, child: Text('Bán kính 50 km')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. DANH SÁCH NGƯỜI DÙNG ACTIVE Ở DƯỚI (Draggable / Floating Bottom Sheet)
          DraggableScrollableSheet(
            initialChildSize: 0.18,
            minChildSize: 0.08,
            maxChildSize: 0.65,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -3)),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đang hoạt động xung quanh (${_activeUsers.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (_activeUsers.isEmpty && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Chưa có người dùng nào chia sẻ vị trí trong phạm vi ${_selectedRadius.toInt()}km.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ..._activeUsers.map((user) {
                        final isMe = user.username.toLowerCase() == _currentUsername?.toLowerCase();
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.15),
                              child: Icon(
                                isMe ? Icons.person : Icons.navigation,
                                color: _getRoleColor(user.role),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              '${user.fullName.isNotEmpty ? user.fullName : user.username} ${isMe ? "(Tôi)" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${user.role} • Cách ${user.distanceInKm != null ? "${user.distanceInKm!.toStringAsFixed(1)} km" : "0 km"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.history, color: Colors.blueGrey, size: 20),
                                  tooltip: 'Xem lộ trình',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LocationHistoryScreen(
                                          userId: user.userId,
                                          userName: user.fullName.isNotEmpty ? user.fullName : user.username,
                                          userRole: user.role,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.center_focus_strong, color: Colors.blue, size: 20),
                                  tooltip: 'Định vị trên bản đồ',
                                  onPressed: () {
                                    if (user.latitude != null && user.longitude != null) {
                                      _safeMoveMap(user.latitude!, user.longitude!);
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              if (user.latitude != null && user.longitude != null) {
                                _safeMoveMap(user.latitude!, user.longitude!);
                                _showUserDetailModal(user);
                              }
                            },
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMyInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_pin, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text('Vị trí của bạn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Toạ độ: ${_myLat.toStringAsFixed(5)}, ${_myLng.toStringAsFixed(5)}'),
            const SizedBox(height: 4),
            Text('Địa chỉ: $_myAddress', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Xem lịch sử di chuyển của tôi'),
                onPressed: () {
                  Navigator.pop(ctx);
                  final me = _activeUsers.where((u) => u.username.toLowerCase() == _currentUsername?.toLowerCase()).firstOrNull;
                  if (me != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationHistoryScreen(
                          userId: me.userId,
                          userName: me.fullName.isNotEmpty ? me.fullName : me.username,
                          userRole: me.role,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailModal(UserLocationModel user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: _getRoleColor(user.role)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isNotEmpty ? user.fullName : user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Vai trò: ${user.role}', style: TextStyle(color: _getRoleColor(user.role))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (user.address != null)
              Text('📍 Địa chỉ: ${user.address}', style: TextStyle(color: Colors.grey.shade800)),
            const SizedBox(height: 4),
            Text('📏 Khoảng cách: ${user.distanceInKm != null ? "${user.distanceInKm!.toStringAsFixed(2)} km" : "Không xác định"}'),
            const SizedBox(height: 4),
            if (user.lastLocationUpdatedAt != null)
              Text('🕒 Cập nhật: ${user.lastLocationUpdatedAt!.toLocal().toString().split(".")[0]}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Định vị'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (user.latitude != null && user.longitude != null) {
                        _safeMoveMap(user.latitude!, user.longitude!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('Xem lộ trình'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationHistoryScreen(
                            userId: user.userId,
                            userName: user.fullName.isNotEmpty ? user.fullName : user.username,
                            userRole: user.role,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

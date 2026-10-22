import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';
import '../common/face_id_card.dart';
import '../location/location_sharing_screen.dart';
import '../call/call_home_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final username = await StorageService.getUsername();
    final role = await StorageService.getRole();
    setState(() {
      _username = username ?? 'Khách hàng';
      _role = role ?? 'Customer';
    });
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Chủ Khách Hàng'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            tooltip: 'Chia sẻ vị trí & Bản đồ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationSharingScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.video_call),
            tooltip: 'Gọi Video Nhóm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CallHomeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Xin chào, $_username!',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text('Vai trò: $_role'),
                      backgroundColor: Colors.teal.shade50,
                      labelStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_username.isNotEmpty)
              FaceIdManagementCard(
                username: _username,
                primaryColor: Colors.teal,
              ),
            const SizedBox(height: 24),
            const Text(
              'Dịch vụ dành cho bạn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildServiceCard(Icons.share_location, 'Vị trí & Bản đồ', Colors.teal, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocationSharingScreen()),
                  );
                }),
                _buildServiceCard(Icons.video_call, 'Gọi Video Nhóm', Colors.indigo, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CallHomeScreen()),
                  );
                }),
                _buildServiceCard(Icons.shopping_bag, 'Sản phẩm', Colors.orange),
                _buildServiceCard(Icons.receipt_long, 'Đơn hàng', Colors.blue),
                _buildServiceCard(Icons.support_agent, 'Hỗ trợ 24/7', Colors.green),
                _buildServiceCard(Icons.settings, 'Cài đặt', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tính năng "$title" đang được phát triển')),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 28,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

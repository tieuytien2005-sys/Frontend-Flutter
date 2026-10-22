import 'package:flutter/material.dart';
import '../../constants/api_constants.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../auth/login_screen.dart';
import 'user_dialogs.dart';
import '../common/face_id_card.dart';
import '../location/location_sharing_screen.dart';
import '../call/call_home_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _adminUsername = '';
  String _adminRole = '';

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminInfo() async {
    final username = await StorageService.getUsername();
    final role = await StorageService.getRole();
    setState(() {
      _adminUsername = username ?? 'Quản trị viên';
      _adminRole = role ?? 'Admin';
    });
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await UserService.getUsers();

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _users = result.data!;
        _filteredUsers = List.from(_users);
        _isLoading = false;
      });
      _onSearchChanged();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Không thể tải danh sách người dùng.';
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final username = user.username.toLowerCase();
          final fullName = user.fullName.toLowerCase();
          final email = user.email.toLowerCase();
          final role = user.role.toLowerCase();
          return username.contains(query) ||
              fullName.contains(query) ||
              email.contains(query) ||
              role.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _handleDeleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa tài khoản "${user.username}" không? Thao tác này không thể hoàn tác.'),
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
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await UserService.deleteUser(user.id);

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa người dùng "${user.username}" thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Xóa thất bại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => CreateUserDialog(
        onUserCreated: _fetchUsers,
      ),
    );
  }

  void _showEditDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => EditUserDialog(
        user: user,
        onUserUpdated: _fetchUsers,
      ),
    );
  }

  void _showDetailsDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => UserDetailsDialog(user: user),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color _getRoleColor(String role) {
    final lower = role.toLowerCase();
    if (lower == ApiConstants.roleAdmin.toLowerCase()) return Colors.deepPurple;
    if (lower == ApiConstants.roleStaff.toLowerCase() || lower == 'employee' || lower == 'nhanvien') {
      return Colors.indigo;
    }
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _users.where((u) => u.role.toLowerCase() == 'admin').length;
    final staffCount = _users.where((u) => u.role.toLowerCase() == 'staff' || u.role.toLowerCase() == 'employee').length;
    final customerCount = _users.length - adminCount - staffCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Quản Trị (Admin)'),
        backgroundColor: Colors.deepPurple,
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _fetchUsers,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm User'),
        onPressed: _showCreateDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Admin Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.admin_panel_settings, size: 38, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, $_adminUsername!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Quyền hạn: $_adminRole',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_adminUsername.isNotEmpty)
                FaceIdManagementCard(
                  username: _adminUsername,
                  primaryColor: Colors.deepPurple,
                ),
              const SizedBox(height: 16),

              // Thống kê người dùng
              Row(
                children: [
                  Expanded(child: _buildStatChip('Tổng', '${_users.length}', Colors.black87)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatChip('Admin', '$adminCount', Colors.deepPurple)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatChip('Staff', '$staffCount', Colors.indigo)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatChip('Customer', '$customerCount', Colors.teal)),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên, username, email, role...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Tiêu đề danh sách
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Danh sách Người dùng (${_filteredUsers.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // User List or States
              if (_isLoading && _users.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _fetchUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                            if (_errorMessage!.contains('401') || _errorMessage!.contains('hết hạn'))
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: _handleLogout,
                                icon: const Icon(Icons.logout, color: Colors.white),
                                label: const Text('Đăng nhập lại', style: TextStyle(color: Colors.white)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredUsers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      children: [
                        Icon(Icons.person_off_outlined, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Không tìm thấy người dùng nào phù hợp',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final roleColor = _getRoleColor(user.role);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDetailsDialog(user),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: roleColor.withValues(alpha: 0.15),
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : user.username[0].toUpperCase(),
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: roleColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            user.role,
                                            style: TextStyle(
                                              color: roleColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${user.username} • ${user.email}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          'SĐT: ${user.phoneNumber}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Nút Sửa (Update)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                tooltip: 'Chỉnh sửa',
                                onPressed: () => _showEditDialog(user),
                              ),
                              // Nút Xóa (Delete)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Xóa user',
                                onPressed: () => _handleDeleteUser(user),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 60), // Khoảng trống cho FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

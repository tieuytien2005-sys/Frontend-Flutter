import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../views/admin/admin_home_screen.dart';
import '../views/customer/customer_home_screen.dart';
import '../views/staff/staff_dashboard_screen.dart';

class RoleRouter {
  static Widget getHomeScreenByRole(String? role) {
    if (role == null) {
      return const CustomerHomeScreen();
    }

    final normalized = role.trim().toLowerCase();

    if (normalized == ApiConstants.roleAdmin.toLowerCase()) {
      return const AdminHomeScreen();
    } else if (normalized == ApiConstants.roleStaff.toLowerCase() ||
        normalized == 'employee' ||
        normalized == 'nhanvien') {
      return const StaffDashboardScreen();
    } else {
      return const CustomerHomeScreen();
    }
  }

  static void navigateByRole(BuildContext context, String? role) {
    final screen = getHomeScreenByRole(role);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }
}

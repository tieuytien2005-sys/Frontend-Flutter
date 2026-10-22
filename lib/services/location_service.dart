import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../constants/api_constants.dart';
import '../models/location_models.dart';
import 'api_client.dart';

class PositionData {
  final double latitude;
  final double longitude;
  final double? speed;
  final bool isFallback;
  final String? message;

  PositionData({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.isFallback = false,
    this.message,
  });
}

class LocationService {
  // Toạ độ mặc định TP. Hồ Chí Minh phục vụ Fallback cho Emulator / Không có GPS
  static const double defaultLatitude = 10.7725;
  static const double defaultLongitude = 106.6980;
  static const String defaultAddress = 'TP. Hồ Chí Minh (Vị trí mô phỏng/Fallback)';

  /// Lấy vị trí GPS của thiết bị với cơ chế Timeout 5s và Fallback an toàn cho Emulator
  static Future<PositionData> getCurrentPositionSafe({
    void Function(String message)? onNotice,
  }) async {
    try {
      // 1. Kiểm tra dịch vụ định vị trên thiết bị
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onNotice?.call('Dịch vụ định vị (GPS) đang tắt. Sử dụng toạ độ mặc định TP.HCM.');
        return PositionData(
          latitude: defaultLatitude,
          longitude: defaultLongitude,
          isFallback: true,
          message: 'Dịch vụ GPS chưa bật',
        );
      }

      // 2. Kiểm tra quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onNotice?.call('Quyền truy cập vị trí bị từ chối. Sử dụng toạ độ mặc định TP.HCM.');
          return PositionData(
            latitude: defaultLatitude,
            longitude: defaultLongitude,
            isFallback: true,
            message: 'Quyền vị trí bị từ chối',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onNotice?.call('Quyền vị trí bị chặn vĩnh viễn. Sử dụng toạ độ mặc định TP.HCM.');
        return PositionData(
          latitude: defaultLatitude,
          longitude: defaultLongitude,
          isFallback: true,
          message: 'Quyền vị trí bị chặn vĩnh viễn',
        );
      }

      // 3. Lấy vị trí thực tế với Timeout bắt buộc 5s chống treo/crash trên Emulator
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return PositionData(
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        isFallback: false,
      );
    } on TimeoutException {
      onNotice?.call('Quá thời gian chờ GPS (Timeout 5s). Tự động dùng toạ độ TP.HCM.');
      return PositionData(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        isFallback: true,
        message: 'GPS Timeout (5s)',
      );
    } catch (e) {
      onNotice?.call('Không thể lấy GPS ($e). Tự động dùng toạ độ TP.HCM.');
      return PositionData(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        isFallback: true,
        message: e.toString(),
      );
    }
  }

  /// Cập nhật vị trí hiện tại lên Backend (POST /api/Locations/update)
  static Future<ApiResponse<dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    double? speed,
  }) async {
    return await ApiClient.post(
      ApiConstants.locationUpdate,
      body: () {
        final b = <String, dynamic>{
          'latitude': latitude,
          'longitude': longitude,
        };
        if (address != null) b['address'] = address;
        if (speed != null) b['speed'] = speed;
        return b;
      }(),
      requiresAuth: true,
    );
  }

  /// Bật/Tắt trạng thái chia sẻ vị trí (POST /api/Locations/toggle-sharing)
  static Future<ApiResponse<dynamic>> toggleSharing(bool isSharing) async {
    return await ApiClient.post(
      ApiConstants.locationToggleSharing,
      body: {
        'isSharing': isSharing,
      },
      requiresAuth: true,
    );
  }

  /// Lấy danh sách người dùng đang chia sẻ vị trí (GET /api/Locations/active)
  static Future<List<UserLocationModel>> getActiveSharingUsers({
    double? latitude,
    double? longitude,
    double radiusInKm = 10.0,
    String? role,
  }) async {
    final queryParams = <String>[];
    if (latitude != null) queryParams.add('latitude=$latitude');
    if (longitude != null) queryParams.add('longitude=$longitude');
    queryParams.add('radiusInKm=$radiusInKm');
    if (role != null && role.isNotEmpty && role != 'All') {
      queryParams.add('role=$role');
    }

    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final url = '${ApiConstants.locationActive}$queryString';

    final res = await ApiClient.get(url, requiresAuth: true);
    if (res.isSuccess && res.data is List) {
      return (res.data as List)
          .map((item) => UserLocationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Xem vị trí của một người dùng cụ thể (GET /api/Locations/user/{userId})
  static Future<UserLocationModel?> getUserLocation(String userId) async {
    final res = await ApiClient.get(
      ApiConstants.locationUser(userId),
      requiresAuth: true,
    );
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      return UserLocationModel.fromJson(res.data as Map<String, dynamic>);
    }
    return null;
  }

  /// Lấy lịch sử lộ trình di chuyển (GET /api/Locations/history/{userId})
  static Future<List<LocationHistoryModel>> getLocationHistory(
    String userId, {
    int limit = 50,
  }) async {
    final res = await ApiClient.get(
      '${ApiConstants.locationHistory(userId)}?limit=$limit',
      requiresAuth: true,
    );
    if (res.isSuccess && res.data is List) {
      return (res.data as List)
          .map((item) => LocationHistoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Xóa lịch sử vị trí của chính mình (DELETE /api/Locations/history)
  static Future<ApiResponse<dynamic>> clearMyHistory() async {
    return await ApiClient.delete(
      ApiConstants.locationDeleteHistory,
      requiresAuth: true,
    );
  }
}

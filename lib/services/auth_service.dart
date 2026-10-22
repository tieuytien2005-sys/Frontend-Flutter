import '../constants/api_constants.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  // 1. Đăng ký tài khoản
  static Future<ApiResponse<String>> register(RegisterRequest request) async {
    final response = await ApiClient.post(
      ApiConstants.register,
      body: request.toJson(),
    );

    if (response.isSuccess) {
      final msg = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : 'Đăng ký tài khoản thành công!';
      return ApiResponse(
        isSuccess: true,
        data: msg,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Đăng ký thất bại.',
        statusCode: response.statusCode,
      );
    }
  }

  // 2. Đăng nhập bước 1 (Xác nhận username + password, gửi OTP)
  static Future<ApiResponse<String>> loginStep1(LoginStep1Request request) async {
    final response = await ApiClient.post(
      ApiConstants.loginStep1,
      body: request.toJson(),
    );

    if (response.isSuccess) {
      String msg = 'Mã OTP đã được gửi đến email của bạn!';
      if (response.data is Map && response.data['message'] != null) {
        msg = response.data['message'].toString();
      } else if (response.data is String && response.data.toString().isNotEmpty) {
        msg = response.data.toString();
      }
      return ApiResponse(
        isSuccess: true,
        data: msg,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Đăng nhập bước 1 thất bại.',
        statusCode: response.statusCode,
      );
    }
  }

  // 3. Đăng nhập bước 2 (Xác nhận mã OTP, nhận JWT token)
  static Future<ApiResponse<AuthResponse>> verifyOtp(VerifyOtpRequest request) async {
    final response = await ApiClient.post(
      ApiConstants.verifyOtp,
      body: request.toJson(),
    );

    if (response.isSuccess) {
      AuthResponse authResponse;
      if (response.data is Map<String, dynamic>) {
        authResponse = AuthResponse.fromJson(response.data);
      } else if (response.data is String) {
        // In case the API returns raw JWT token string
        authResponse = AuthResponse.fromJson({'token': response.data});
      } else {
        authResponse = AuthResponse(isSuccess: true);
      }

      // Lưu Token và Role vào SharedPreferences nếu có token
      if (authResponse.token != null && authResponse.token!.isNotEmpty) {
        await StorageService.saveAuthData(
          token: authResponse.token!,
          role: authResponse.role ?? ApiConstants.roleCustomer,
          username: authResponse.username ?? request.username,
          fullName: authResponse.fullName,
          email: authResponse.email,
        );
      }

      return ApiResponse(
        isSuccess: true,
        data: authResponse,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Mã OTP không chính xác hoặc đã hết hạn.',
        statusCode: response.statusCode,
      );
    }
  }

  // Đăng xuất
  static Future<void> logout() async {
    await StorageService.clearAuth();
  }
}

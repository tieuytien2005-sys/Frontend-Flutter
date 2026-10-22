import '../constants/api_constants.dart';
import '../models/auth_models.dart';
import '../models/face_models.dart';
import 'api_client.dart';
import 'storage_service.dart';

class FaceApiService {
  // 1. Đăng ký khuôn mặt (Yêu cầu Bearer Token)
  static Future<ApiResponse<String>> registerFace(
    String username,
    List<double> embedding, {
    String? imageBase64,
  }) async {
    final dto = RegisterFaceDto(
      username: username,
      faceEmbedding: embedding,
      faceImageUrl: imageBase64,
    );

    final response = await ApiClient.post(
      ApiConstants.registerFace,
      body: dto.toJson(),
      requiresAuth: true,
    );

    if (response.isSuccess) {
      String msg = 'Đăng ký khuôn mặt thành công!';
      if (response.data is Map && response.data['message'] != null) {
        msg = response.data['message'].toString();
      } else if (response.data is String && response.data.toString().isNotEmpty) {
        msg = response.data.toString();
      }
      // Lưu trạng thái Face ID đã đăng ký thành công vào local cache
      await StorageService.setFaceRegistered(username, true);

      return ApiResponse(
        isSuccess: true,
        data: msg,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Đăng ký khuôn mặt thất bại.',
        statusCode: response.statusCode,
      );
    }
  }

  // 2. Đăng nhập bằng khuôn mặt (1:1 hoặc 1:N)
  static Future<ApiResponse<AuthResponse>> loginFace(
    List<double> embedding, {
    String? username,
    double threshold = 0.70,
  }) async {
    final dto = LoginFaceDto(
      faceEmbedding: embedding,
      username: username,
      threshold: threshold,
    );

    final response = await ApiClient.post(
      ApiConstants.loginFace,
      body: dto.toJson(),
      requiresAuth: false,
    );

    if (response.isSuccess) {
      AuthResponse authResponse;
      if (response.data is Map<String, dynamic>) {
        authResponse = AuthResponse.fromJson(response.data);
      } else if (response.data is String) {
        authResponse = AuthResponse.fromJson({'token': response.data});
      } else {
        authResponse = AuthResponse(isSuccess: true);
      }

      final resolvedUsername = authResponse.username ?? username ?? '';

      // Lưu Token và Role vào SharedPreferences
      if (authResponse.token != null && authResponse.token!.isNotEmpty) {
        await StorageService.saveAuthData(
          token: authResponse.token!,
          role: authResponse.role ?? ApiConstants.roleCustomer,
          username: resolvedUsername,
          fullName: authResponse.fullName,
          email: authResponse.email,
        );
      }

      // Đăng nhập Face thành công chứng tỏ user đã đăng ký Face ID
      if (resolvedUsername.isNotEmpty) {
        await StorageService.setFaceRegistered(resolvedUsername, true);
      }

      return ApiResponse(
        isSuccess: true,
        data: authResponse,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Không nhận diện được khuôn mặt phù hợp.',
        statusCode: response.statusCode,
      );
    }
  }

  // 3. Kiểm tra trạng thái khuôn mặt
  static Future<ApiResponse<FaceStatusResponse>> getFaceStatus(String username) async {
    final response = await ApiClient.get(
      ApiConstants.faceStatus(username),
      requiresAuth: false,
    );

    if (response.isSuccess) {
      final status = FaceStatusResponse.fromJson(response.data);
      // Đồng bộ trạng thái vào local cache
      await StorageService.setFaceRegistered(username, status.hasFace);

      return ApiResponse(
        isSuccess: true,
        data: status,
        statusCode: response.statusCode,
      );
    } else {
      // Khi mất mạng hoặc lỗi, đọc fallback từ local cache
      final cached = await StorageService.isFaceRegistered(username);
      return ApiResponse(
        isSuccess: true,
        data: FaceStatusResponse(hasFace: cached),
        statusCode: response.statusCode,
      );
    }
  }

  // 4. Xóa dữ liệu khuôn mặt (Yêu cầu Bearer Token)
  static Future<ApiResponse<bool>> removeFace(String username) async {
    final response = await ApiClient.delete(
      ApiConstants.removeFace(username),
      requiresAuth: true,
    );

    if (response.isSuccess) {
      await StorageService.setFaceRegistered(username, false);
      return ApiResponse(
        isSuccess: true,
        data: true,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Xóa dữ liệu khuôn mặt thất bại.',
        statusCode: response.statusCode,
      );
    }
  }
}

import '../constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  // Lấy danh sách users (Dành cho Admin)
  static Future<ApiResponse<List<UserModel>>> getUsers() async {
    final response = await ApiClient.get(
      ApiConstants.users,
      requiresAuth: true,
    );

    if (response.isSuccess) {
      final List<UserModel> users = [];
      if (response.data is List) {
        for (var item in response.data) {
          if (item is Map<String, dynamic>) {
            users.add(UserModel.fromJson(item));
          }
        }
      } else if (response.data is Map && response.data['data'] is List) {
        for (var item in response.data['data']) {
          if (item is Map<String, dynamic>) {
            users.add(UserModel.fromJson(item));
          }
        }
      }
      return ApiResponse(
        isSuccess: true,
        data: users,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Không thể tải danh sách người dùng.',
        statusCode: response.statusCode,
      );
    }
  }

  // Lấy chi tiết user theo ID
  static Future<ApiResponse<UserModel>> getUserById(String id) async {
    final response = await ApiClient.get(
      '${ApiConstants.users}/$id',
      requiresAuth: true,
    );

    if (response.isSuccess && response.data is Map<String, dynamic>) {
      return ApiResponse(
        isSuccess: true,
        data: UserModel.fromJson(response.data),
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Không tìm thấy người dùng.',
        statusCode: response.statusCode,
      );
    }
  }

  // Cập nhật thông tin user
  static Future<ApiResponse<bool>> updateUser(String id, UpdateUserRequest request) async {
    final response = await ApiClient.put(
      '${ApiConstants.users}/$id',
      body: request.toJson(),
      requiresAuth: true,
    );

    if (response.isSuccess) {
      return ApiResponse(
        isSuccess: true,
        data: true,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Cập nhật thất bại.',
        statusCode: response.statusCode,
      );
    }
  }

  // Xóa user
  static Future<ApiResponse<bool>> deleteUser(String id) async {
    final response = await ApiClient.delete(
      '${ApiConstants.users}/$id',
      requiresAuth: true,
    );

    if (response.isSuccess) {
      return ApiResponse(
        isSuccess: true,
        data: true,
        statusCode: response.statusCode,
      );
    } else {
      return ApiResponse(
        isSuccess: false,
        errorMessage: response.errorMessage ?? 'Xóa người dùng thất bại.',
        statusCode: response.statusCode,
      );
    }
  }
}

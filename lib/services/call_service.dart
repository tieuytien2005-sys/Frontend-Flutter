import '../constants/api_constants.dart';
import '../models/call_models.dart';
import 'api_client.dart';

class CallService {
  /// 1. Tạo phòng gọi video nhóm mới (POST /api/Call/rooms)
  static Future<ApiResponse<CallRoomModel>> createRoom({
    required String title,
    int maxParticipants = 10,
  }) async {
    final res = await ApiClient.post(
      ApiConstants.callRooms,
      body: {
        'title': title.trim(),
        'maxParticipants': maxParticipants,
      },
      requiresAuth: true,
    );

    if (res.isSuccess && res.data is Map<String, dynamic>) {
      return ApiResponse<CallRoomModel>(
        isSuccess: true,
        data: CallRoomModel.fromJson(res.data as Map<String, dynamic>),
        statusCode: res.statusCode,
      );
    }

    return ApiResponse<CallRoomModel>(
      isSuccess: false,
      errorMessage: res.errorMessage ?? 'Không thể tạo phòng gọi',
      statusCode: res.statusCode,
    );
  }

  /// 2. Lấy thông tin phòng gọi và danh sách người tham gia (GET /api/Call/rooms/{roomCode})
  static Future<ApiResponse<CallRoomModel>> getRoomDetails(String roomCode) async {
    final res = await ApiClient.get(
      ApiConstants.callRoomDetails(roomCode.trim()),
      requiresAuth: true,
    );

    if (res.isSuccess && res.data is Map<String, dynamic>) {
      return ApiResponse<CallRoomModel>(
        isSuccess: true,
        data: CallRoomModel.fromJson(res.data as Map<String, dynamic>),
        statusCode: res.statusCode,
      );
    }

    return ApiResponse<CallRoomModel>(
      isSuccess: false,
      errorMessage: res.errorMessage ?? 'Không tìm thấy phòng gọi hoặc phòng đã đóng',
      statusCode: res.statusCode,
    );
  }

  /// 3. Kết thúc phòng gọi nhóm (POST /api/Call/rooms/{roomCode}/end)
  /// Phân quyền: Chỉ Chủ phòng (Host) hoặc Admin mới được phép đóng phòng
  static Future<ApiResponse<EndCallResponseModel>> endRoom(String roomCode) async {
    final res = await ApiClient.post(
      ApiConstants.callRoomEnd(roomCode.trim()),
      requiresAuth: true,
    );

    if (res.isSuccess && res.data is Map<String, dynamic>) {
      return ApiResponse<EndCallResponseModel>(
        isSuccess: true,
        data: EndCallResponseModel.fromJson(res.data as Map<String, dynamic>),
        statusCode: res.statusCode,
      );
    }

    return ApiResponse<EndCallResponseModel>(
      isSuccess: false,
      errorMessage: res.errorMessage ?? 'Không thể kết thúc phòng gọi',
      statusCode: res.statusCode,
    );
  }

  /// 4. Lấy lịch sử 50 cuộc gọi nhóm đã tham gia hoặc tạo (GET /api/Call/history)
  static Future<List<CallRoomModel>> getCallHistory() async {
    final res = await ApiClient.get(
      ApiConstants.callHistory,
      requiresAuth: true,
    );

    if (res.isSuccess && res.data is List) {
      return (res.data as List)
          .map((item) => CallRoomModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }
}
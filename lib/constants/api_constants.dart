class ApiConstants {
  static const String baseUrl = 'https://fastsparklyshop42.conveyor.cloud';

  // Auth Endpoints
  static const String register = '$baseUrl/api/Auth/register';
  static const String loginStep1 = '$baseUrl/api/Auth/login-step1';
  static const String verifyOtp = '$baseUrl/api/Auth/verify-otp';

  // Face Recognition Endpoints
  static const String registerFace = '$baseUrl/api/Auth/register-face';
  static const String loginFace = '$baseUrl/api/Auth/login-face';
  static String faceStatus(String username) =>
      '$baseUrl/api/Auth/face-status/$username';
  static String removeFace(String username) =>
      '$baseUrl/api/Auth/remove-face/$username';

  // User Endpoints
  static const String users = '$baseUrl/api/Users';

  // Location Endpoints
  static const String locationUpdate = '$baseUrl/api/Locations/update';
  static const String locationToggleSharing =
      '$baseUrl/api/Locations/toggle-sharing';
  static const String locationActive = '$baseUrl/api/Locations/active';
  static String locationUser(String userId) =>
      '$baseUrl/api/Locations/user/$userId';
  static String locationHistory(String userId) =>
      '$baseUrl/api/Locations/history/$userId';
  static const String locationDeleteHistory = '$baseUrl/api/Locations/history';

  // Video Call Endpoints
  static const String callRooms = '$baseUrl/api/Call/rooms';
  static String callRoomDetails(String roomCode) =>
      '$baseUrl/api/Call/rooms/$roomCode';
  static String callRoomEnd(String roomCode) =>
      '$baseUrl/api/Call/rooms/$roomCode/end';
  static const String callHistory = '$baseUrl/api/Call/history';

  // Roles
  static const String roleAdmin = 'Admin';
  static const String roleStaff = 'Staff';
  static const String roleCustomer = 'Customer';

  static const List<String> availableRoles = [
    roleCustomer,
    roleStaff,
    roleAdmin,
  ];
}

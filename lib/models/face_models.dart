class RegisterFaceDto {
  final String username;
  final List<double> faceEmbedding;
  final String? faceImageUrl;

  RegisterFaceDto({
    required this.username,
    required this.faceEmbedding,
    this.faceImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'faceEmbedding': faceEmbedding,
      if (faceImageUrl != null) 'faceImageUrl': faceImageUrl,
    };
  }
}

class LoginFaceDto {
  final List<double> faceEmbedding;
  final String? username;
  final double threshold;

  LoginFaceDto({
    required this.faceEmbedding,
    this.username,
    this.threshold = 0.70,
  });

  Map<String, dynamic> toJson() {
    return {
      'faceEmbedding': faceEmbedding,
      if (username != null && username!.isNotEmpty) 'username': username,
      'threshold': threshold,
    };
  }
}

class FaceStatusResponse {
  final bool hasFace;
  final String? message;
  final String? registeredAt;
  final String? faceImageUrl;

  FaceStatusResponse({
    required this.hasFace,
    this.message,
    this.registeredAt,
    this.faceImageUrl,
  });

  factory FaceStatusResponse.fromJson(dynamic json) {
    if (json == null) return FaceStatusResponse(hasFace: false);
    if (json is bool) {
      return FaceStatusResponse(hasFace: json);
    }
    if (json is Map) {
      final val = json['isFaceRegistered'] ??
          json['IsFaceRegistered'] ??
          json['hasFace'] ??
          json['HasFace'] ??
          json['hasFaceRegistered'] ??
          json['HasFaceRegistered'] ??
          json['isRegistered'] ??
          json['IsRegistered'] ??
          json['data'];

      bool isRegistered = false;
      if (val is bool) {
        isRegistered = val;
      } else if (val is num) {
        isRegistered = val == 1;
      } else if (val is String) {
        isRegistered = val.toLowerCase() == 'true';
      }

      return FaceStatusResponse(
        hasFace: isRegistered,
        message: (json['message'] ?? json['Message'])?.toString(),
        registeredAt: (json['registeredAt'] ?? json['RegisteredAt'] ?? json['createdAt'])?.toString(),
        faceImageUrl: (json['faceImageUrl'] ?? json['FaceImageUrl'])?.toString(),
      );
    }
    return FaceStatusResponse(hasFace: false);
  }
}

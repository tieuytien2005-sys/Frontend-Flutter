class CallParticipantModel {
  final String userId;
  final String username;
  final String fullName;
  final String? connectionId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isMuted;
  final bool isCameraOff;
  final bool isOnline;

  CallParticipantModel({
    required this.userId,
    required this.username,
    required this.fullName,
    this.connectionId,
    required this.joinedAt,
    this.leftAt,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isOnline = true,
  });

  factory CallParticipantModel.fromJson(Map<String, dynamic> json) {
    return CallParticipantModel(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      connectionId: json['connectionId']?.toString(),
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      leftAt: json['leftAt'] != null
          ? DateTime.tryParse(json['leftAt'].toString())
          : null,
      isMuted: json['isMuted'] == true,
      isCameraOff: json['isCameraOff'] == true,
      isOnline: json['isOnline'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'fullName': fullName,
      'connectionId': connectionId,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'isMuted': isMuted,
      'isCameraOff': isCameraOff,
      'isOnline': isOnline,
    };
  }
}

class CallRoomModel {
  final int id;
  final String roomCode;
  final String title;
  final String hostUserId;
  final String? hostName;
  final String status;
  final int maxParticipants;
  final int activeParticipantCount;
  final DateTime createdAt;
  final DateTime? endedAt;
  final List<CallParticipantModel> participants;

  CallRoomModel({
    required this.id,
    required this.roomCode,
    required this.title,
    required this.hostUserId,
    this.hostName,
    required this.status,
    required this.maxParticipants,
    required this.activeParticipantCount,
    required this.createdAt,
    this.endedAt,
    this.participants = const [],
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isEnded => status.toLowerCase() == 'ended';

  factory CallRoomModel.fromJson(Map<String, dynamic> json) {
    var rawParticipants = json['participants'];
    List<CallParticipantModel> pList = [];
    if (rawParticipants is List) {
      pList = rawParticipants
          .map((p) => CallParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    return CallRoomModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomCode: json['roomCode']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Phòng gọi nhóm',
      hostUserId: json['hostUserId']?.toString() ?? '',
      hostName: json['hostName']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 10,
      activeParticipantCount: (json['activeParticipantCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      participants: pList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomCode': roomCode,
      'title': title,
      'hostUserId': hostUserId,
      'hostName': hostName,
      'status': status,
      'maxParticipants': maxParticipants,
      'activeParticipantCount': activeParticipantCount,
      'createdAt': createdAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
    };
  }
}

class EndCallResponseModel {
  final String roomCode;
  final String message;
  final DateTime endedAt;

  EndCallResponseModel({
    required this.roomCode,
    required this.message,
    required this.endedAt,
  });

  factory EndCallResponseModel.fromJson(Map<String, dynamic> json) {
    return EndCallResponseModel(
      roomCode: json['roomCode']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
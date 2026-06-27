class UserModel {
  final String id;
  final String firebaseUid;
  final String displayName;
  final String? avatarUrl;
  final String authProvider;
  final String? email;
  final String? phoneNumber;
  final bool isGuest;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.firebaseUid,
    required this.displayName,
    this.avatarUrl,
    required this.authProvider,
    this.email,
    this.phoneNumber,
    this.isGuest = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      firebaseUid: json['firebaseUid'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      authProvider: json['authProvider'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firebaseUid': firebaseUid,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'authProvider': authProvider,
    'email': email,
    'phoneNumber': phoneNumber,
    'isGuest': isGuest,
    'createdAt': createdAt.toIso8601String(),
  };
}

import 'package:equatable/equatable.dart';

class RegisterUserRequest extends Equatable {
  final String email;
  final String password;
  final String? avatarUrl;
  final String invitationToken;

  const RegisterUserRequest({
    required this.email,
    required this.password,
    this.avatarUrl,
    required this.invitationToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'invitation_token': invitationToken,
    };
  }

  @override
  List<Object?> get props => [email, password, avatarUrl, invitationToken];
}

class RegisterUserResponse extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final List<String> joinedVerse;
  final String token;
  final String? refreshToken;
  final String? pendingVerseJoin;

  const RegisterUserResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.joinedVerse,
    required this.token,
    this.refreshToken,
    this.pendingVerseJoin,
  });

  factory RegisterUserResponse.fromJson(Map<String, dynamic> json) {
    return RegisterUserResponse(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'],
      joinedVerse: List<String>.from(json['joined_verse'] ?? []),
      token: json['token'] ?? '',
      refreshToken: json['refresh_token'], // May be null
      pendingVerseJoin: json['pending_verse_join'],
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    firstName,
    lastName,
    avatarUrl,
    joinedVerse,
    token,
    refreshToken,
    pendingVerseJoin,
  ];
}

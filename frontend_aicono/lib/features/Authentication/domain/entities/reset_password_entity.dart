import 'package:equatable/equatable.dart';

// Reset Password Request Entity
class ResetPasswordRequest extends Equatable {
  final String email;
  final String password;
  final String confirmPassword;

  const ResetPasswordRequest({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [email, password, confirmPassword];

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password};
  }
}

// Reset Password Response Entity
class ResetPasswordResponse extends Equatable {
  final String message;
  final bool success;
  final String? token;

  const ResetPasswordResponse({
    required this.message,
    required this.success,
    this.token,
  });

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      message: json['message'] ?? '',
      success: json['success'] ?? false,
      token: json['token'],
    );
  }

  @override
  List<Object?> get props => [message, success, token];
}

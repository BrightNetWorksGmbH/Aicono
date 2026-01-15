import 'package:equatable/equatable.dart';

class LoxoneConnectionRequest extends Equatable {
  final String user;
  final String pass;
  final String externalAddress;
  final int port;
  final String serialNumber;

  const LoxoneConnectionRequest({
    required this.user,
    required this.pass,
    required this.externalAddress,
    required this.port,
    required this.serialNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'pass': pass,
      'externalAddress': externalAddress,
      'port': port,
      'serialNumber': serialNumber,
    };
  }

  @override
  List<Object?> get props => [user, pass, externalAddress, port, serialNumber];
}

class LoxoneConnectionResponse extends Equatable {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const LoxoneConnectionResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory LoxoneConnectionResponse.fromJson(Map<String, dynamic> json) {
    return LoxoneConnectionResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  @override
  List<Object?> get props => [success, message, data];
}


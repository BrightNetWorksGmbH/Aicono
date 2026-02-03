import 'package:equatable/equatable.dart';

/// Recipient info from report token/info API.
class ReportTokenRecipientEntity extends Equatable {
  final String id;
  final String name;
  final String email;

  const ReportTokenRecipientEntity({
    required this.id,
    required this.name,
    required this.email,
  });

  factory ReportTokenRecipientEntity.fromJson(Map<String, dynamic> json) {
    return ReportTokenRecipientEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, email];
}

/// Building summary from report token/info API.
class ReportTokenBuildingEntity extends Equatable {
  final String id;
  final String name;

  const ReportTokenBuildingEntity({required this.id, required this.name});

  factory ReportTokenBuildingEntity.fromJson(Map<String, dynamic> json) {
    return ReportTokenBuildingEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// Reporting config from report token/info API.
class ReportTokenReportingEntity extends Equatable {
  final String id;
  final String name;
  final String interval;
  final List<String> reportContents;

  const ReportTokenReportingEntity({
    required this.id,
    required this.name,
    required this.interval,
    this.reportContents = const [],
  });

  factory ReportTokenReportingEntity.fromJson(Map<String, dynamic> json) {
    final raw = json['reportContents'];
    final List<String> contents = (raw is List)
        ? raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return ReportTokenReportingEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      interval: (json['interval'] ?? '').toString(),
      reportContents: contents,
    );
  }

  @override
  List<Object?> get props => [id, name, interval];
}

/// Time range from report token/info API.
class ReportTokenTimeRangeEntity extends Equatable {
  final String startDate;
  final String endDate;

  const ReportTokenTimeRangeEntity({
    required this.startDate,
    required this.endDate,
  });

  factory ReportTokenTimeRangeEntity.fromJson(Map<String, dynamic> json) {
    return ReportTokenTimeRangeEntity(
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [startDate, endDate];
}

/// Response from GET /api/v1/reporting/token/info?token=...
class ReportTokenInfoEntity extends Equatable {
  final ReportTokenRecipientEntity recipient;
  final ReportTokenBuildingEntity building;
  final ReportTokenReportingEntity reporting;
  final ReportTokenTimeRangeEntity timeRange;
  final String interval;
  final String generatedAt;

  const ReportTokenInfoEntity({
    required this.recipient,
    required this.building,
    required this.reporting,
    required this.timeRange,
    required this.interval,
    required this.generatedAt,
  });

  factory ReportTokenInfoEntity.fromJson(Map<String, dynamic> json) {
    return ReportTokenInfoEntity(
      recipient: json['recipient'] is Map<String, dynamic>
          ? ReportTokenRecipientEntity.fromJson(
              json['recipient'] as Map<String, dynamic>,
            )
          : const ReportTokenRecipientEntity(id: '', name: '', email: ''),
      building: json['building'] is Map<String, dynamic>
          ? ReportTokenBuildingEntity.fromJson(
              json['building'] as Map<String, dynamic>,
            )
          : const ReportTokenBuildingEntity(id: '', name: ''),
      reporting: json['reporting'] is Map<String, dynamic>
          ? ReportTokenReportingEntity.fromJson(
              json['reporting'] as Map<String, dynamic>,
            )
          : const ReportTokenReportingEntity(id: '', name: '', interval: ''),
      timeRange: json['timeRange'] is Map<String, dynamic>
          ? ReportTokenTimeRangeEntity.fromJson(
              json['timeRange'] as Map<String, dynamic>,
            )
          : const ReportTokenTimeRangeEntity(startDate: '', endDate: ''),
      interval: (json['interval'] ?? '').toString(),
      generatedAt: (json['generatedAt'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [
    recipient.id,
    building.id,
    reporting.id,
    interval,
    generatedAt,
  ];
}

class ReportTokenInfoResponse {
  final bool success;
  final ReportTokenInfoEntity? data;

  const ReportTokenInfoResponse({required this.success, this.data});

  factory ReportTokenInfoResponse.fromJson(Map<String, dynamic> json) {
    ReportTokenInfoEntity? info;
    if (json['success'] == true && json['data'] != null) {
      final dataMap = json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null;
      if (dataMap != null) {
        info = ReportTokenInfoEntity.fromJson(dataMap);
      }
    }
    return ReportTokenInfoResponse(
      success: json['success'] == true,
      data: info,
    );
  }
}

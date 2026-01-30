import 'package:equatable/equatable.dart';

/// Recipient for a report
class ReportRecipientEntity extends Equatable {
  final String recipientId;
  final String recipientName;
  final String recipientEmail;

  const ReportRecipientEntity({
    required this.recipientId,
    required this.recipientName,
    required this.recipientEmail,
  });

  factory ReportRecipientEntity.fromJson(Map<String, dynamic> json) {
    return ReportRecipientEntity(
      recipientId: (json['recipientId'] ?? '').toString(),
      recipientName: (json['recipientName'] ?? '').toString(),
      recipientEmail: (json['recipientEmail'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [recipientId, recipientEmail];
}

/// Report summary from API: /api/v1/dashboard/reports/buildings/{buildingId}/reports
class ReportSummaryEntity extends Equatable {
  final String reportId;
  final String reportName;
  final String interval;
  final String buildingId;
  final String buildingName;
  final List<ReportRecipientEntity> recipients;

  const ReportSummaryEntity({
    required this.reportId,
    required this.reportName,
    required this.interval,
    required this.buildingId,
    required this.buildingName,
    this.recipients = const [],
  });

  factory ReportSummaryEntity.fromJson(Map<String, dynamic> json) {
    final rawRecipients = json['recipients'];
    final List<ReportRecipientEntity> recipientsList = (rawRecipients is List)
        ? rawRecipients
              .whereType<Map<String, dynamic>>()
              .map((e) => ReportRecipientEntity.fromJson(e))
              .toList()
        : <ReportRecipientEntity>[];
    return ReportSummaryEntity(
      reportId: (json['reportId'] ?? '').toString(),
      reportName: (json['reportName'] ?? '').toString(),
      interval: (json['interval'] ?? '').toString(),
      buildingId: (json['buildingId'] ?? '').toString(),
      buildingName: (json['buildingName'] ?? '').toString(),
      recipients: recipientsList,
    );
  }

  @override
  List<Object?> get props => [reportId, reportName, buildingId];
}

class BuildingReportsResponse {
  final bool success;
  final List<ReportSummaryEntity> data;
  final int count;

  const BuildingReportsResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory BuildingReportsResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List<ReportSummaryEntity> reports = (rawData is List)
        ? rawData
              .whereType<Map<String, dynamic>>()
              .map((e) => ReportSummaryEntity.fromJson(e))
              .toList()
        : <ReportSummaryEntity>[];
    return BuildingReportsResponse(
      success: json['success'] == true,
      data: reports,
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse('${json['count']}') ?? reports.length,
    );
  }
}

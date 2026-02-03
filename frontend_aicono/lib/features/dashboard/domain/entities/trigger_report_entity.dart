import 'package:equatable/equatable.dart';

/// Response from POST /api/v1/reporting/trigger/:interval
class TriggerReportEntity extends Equatable {
  final String status;
  final String interval;
  final String? note;

  const TriggerReportEntity({
    required this.status,
    required this.interval,
    this.note,
  });

  factory TriggerReportEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return const TriggerReportEntity(status: 'unknown', interval: '');
    }
    return TriggerReportEntity(
      status: (data['status'] ?? '').toString(),
      interval: (data['interval'] ?? '').toString(),
      note: (data['note'] as String?),
    );
  }

  @override
  List<Object?> get props => [status, interval, note];
}

class TriggerReportResponse {
  final bool success;
  final String message;
  final TriggerReportEntity? data;

  const TriggerReportResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory TriggerReportResponse.fromJson(Map<String, dynamic> json) {
    TriggerReportEntity? dataEntity;
    if (json['data'] != null && json['data'] is Map<String, dynamic>) {
      dataEntity = TriggerReportEntity.fromJson(json);
    }
    return TriggerReportResponse(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      data: dataEntity,
    );
  }
}

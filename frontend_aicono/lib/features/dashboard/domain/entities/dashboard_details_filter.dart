import 'package:equatable/equatable.dart';

/// Optional query parameters for site, building, floor, and room detail APIs.
/// All fields are optional. Omitted fields are not sent to the API.
class DashboardDetailsFilter extends Equatable {
  const DashboardDetailsFilter({
    this.startDate,
    this.endDate,
    this.days,
    this.resolution,
    this.measurementType,
    this.includeMeasurements,
    this.limit,
  });

  /// Start date (ISO 8601), e.g. 2024-01-01T00:00:00Z
  final String? startDate;

  /// End date (ISO 8601), e.g. 2024-01-08T00:00:00Z
  final String? endDate;

  /// Number of days (e.g. 7, 30)
  final int? days;

  /// Resolution override (e.g. 60 for minutes)
  final int? resolution;

  /// Filter by type: Energy, Temperature, etc.
  final String? measurementType;

  /// Include measurement data (default on API is true)
  final bool? includeMeasurements;

  /// Limit measurements (default on API is 1000)
  final int? limit;

  @override
  List<Object?> get props => [
        startDate,
        endDate,
        days,
        resolution,
        measurementType,
        includeMeasurements,
        limit,
      ];

  /// Returns a map suitable for HTTP query parameters. Only non-null fields are included.
  Map<String, dynamic> toQueryMap() {
    final map = <String, dynamic>{};
    if (startDate != null) map['startDate'] = startDate;
    if (endDate != null) map['endDate'] = endDate;
    if (days != null) map['days'] = days;
    if (resolution != null) map['resolution'] = resolution;
    if (measurementType != null) map['measurementType'] = measurementType;
    if (includeMeasurements != null) {
      map['includeMeasurements'] = includeMeasurements.toString();
    }
    if (limit != null) map['limit'] = limit;
    return map;
  }
}

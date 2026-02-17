import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend_aicono/core/injection_container.dart';
import 'package:frontend_aicono/core/services/token_service.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/core/utils/locale_number_format.dart';
import 'package:frontend_aicono/features/realtime/presentation/bloc/realtime_sensor_bloc.dart';

import '../../../../../core/routing/routeLists.dart';
import 'dashboard_shared_components.dart';
import 'connection_status_indicator.dart';

/// Connects to WebSocket and displays live sensor values for a room.
class RoomRealtimeSensorsSection extends StatefulWidget {
  final String roomId;
  final List<dynamic> sensors;

  const RoomRealtimeSensorsSection({
    super.key,
    required this.roomId,
    required this.sensors,
  });

  @override
  State<RoomRealtimeSensorsSection> createState() =>
      _RoomRealtimeSensorsSectionState();
}

class _RoomRealtimeSensorsSectionState extends State<RoomRealtimeSensorsSection> {
  @override
  void initState() {
    super.initState();
    _connectAndSubscribe();
  }

  @override
  void dispose() {
    context.read<RealtimeSensorBloc>().add(
      const RealtimeSensorDisconnectRequested(),
    );
    super.dispose();
  }

  Future<void> _connectAndSubscribe() async {
    final token = await sl<TokenService>().getAccessToken();
    if (token == null || token.isEmpty) return;
    context.read<RealtimeSensorBloc>().add(
      RealtimeSensorConnectRequested(token),
    );
    context.read<RealtimeSensorBloc>().add(
      RealtimeSensorSubscribeToRoom(widget.roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RealtimeSensorBloc, RealtimeSensorState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  onPressed: () {
                    context.pushNamed(
                      Routelists.editRoom,
                      queryParameters: {'roomId': widget.roomId},
                    );
                  },
                  child: Text(
                    'Configure sensors in the room',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live room sensors',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Streaming real-time values from all connected sensors in this room.',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConnectionStatusIndicator(status: state.status),
                ],
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.red[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          context.read<RealtimeSensorBloc>().add(
                            const RealtimeSensorReconnectRequested(),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.sensors.isEmpty)
                Text(
                  'No sensors in this room.',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.grey[700],
                  ),
                )
              else
                ...widget.sensors.map((s) {
                  final sensorId = (s is Map) ? s['_id']?.toString() : null;
                  final name = (s is Map)
                      ? s['name']?.toString() ?? 'Sensor'
                      : 'Sensor';
                  final realtimeValue = sensorId != null
                      ? state.getSensorValue(sensorId)
                      : null;
                  final formattedValue = realtimeValue != null
                      ? '${LocaleNumberFormat.formatNum(
                          realtimeValue.value,
                          locale: context.locale,
                          decimalDigits: 3,
                          fallback: '–',
                        )}${realtimeValue.unit.isNotEmpty ? ' ${realtimeValue.unit}' : ''}'
                      : '—';
                  final hasLiveValue = realtimeValue != null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: hasLiveValue
                            ? const Color(0xFF22C55E).withOpacity(0.4)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        buildDashboardSvgIcon(
                          assetSensor,
                          color: hasLiveValue
                              ? const Color(0xFF38BDF8)
                              : Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formattedValue,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hasLiveValue
                                ? const Color(0xFF22C55E)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/realtime/domain/entities/realtime_connection_state.dart';

/// Displays realtime connection status (Live, Connecting, Disconnected, Offline).
class ConnectionStatusIndicator extends StatelessWidget {
  final RealtimeConnectionStatus status;

  const ConnectionStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case RealtimeConnectionStatus.connected:
      case RealtimeConnectionStatus.subscribed:
        color = const Color(0xFF22C55E);
        label = 'Live';
        break;
      case RealtimeConnectionStatus.connecting:
      case RealtimeConnectionStatus.reconnecting:
        color = const Color(0xFFFBBF24);
        label = 'Connecting...';
        break;
      case RealtimeConnectionStatus.error:
        color = const Color(0xFFFB7185);
        label = 'Disconnected';
        break;
      default:
        color = Colors.grey[500]!;
        label = 'Offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                if (status == RealtimeConnectionStatus.connected ||
                    status == RealtimeConnectionStatus.subscribed)
                  BoxShadow(
                    color: color.withOpacity(0.7),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

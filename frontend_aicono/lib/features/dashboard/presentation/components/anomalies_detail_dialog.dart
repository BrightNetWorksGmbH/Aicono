import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

/// Dialog that displays the full list of anomalies when user taps "Detail View".
class AnomaliesDetailDialog extends StatelessWidget {
  final List<Map> anomalies;

  const AnomaliesDetailDialog({super.key, required this.anomalies});

  /// Shows the anomalies detail dialog.
  static void show(BuildContext context, List<Map> anomalies) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AnomaliesDetailDialog(anomalies: anomalies),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Anomalies',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: anomalies.length,
                itemBuilder: (context, index) {
                  return _AnomalyTile(anomaly: anomalies[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final Map anomaly;

  const _AnomalyTile({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final ts = anomaly['timestamp']?.toString() ?? '';
    final sensor = anomaly['sensorName']?.toString() ?? '—';
    final rule = anomaly['violatedRule']?.toString() ?? '';
    final severity = anomaly['severity']?.toString() ?? '—';
    final value = anomaly['value']?.toString() ?? '—';
    final status = anomaly['status']?.toString() ?? '—';
    Color severityColor = Colors.grey[700]!;
    if (severity == 'High') severityColor = Colors.red[700]!;
    if (severity == 'Medium') severityColor = Colors.orange[700]!;
    if (severity == 'Low') severityColor = Colors.amber[700]!;

    String timeStr = ts;
    if (ts.length > 19) timeStr = ts.substring(0, 19).replaceFirst('T', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  severity,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                status,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sensor,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (rule.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rule,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (value != '—')
            Text(
              'Value: $value',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}

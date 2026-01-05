import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';

class DeleteVerseConfirmationDialog extends StatelessWidget {
  final String verseName;
  final VoidCallback onConfirm;

  const DeleteVerseConfirmationDialog({
    super.key,
    required this.verseName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red[50]),
            child: Icon(
              Icons.warning_rounded,
              color: Colors.red[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'superadmin.delete_verse.title'.tr(),
              style: AppTextStyles.titleLarge.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'superadmin.delete_verse.message'.tr(
              namedArgs: {'verseName': verseName},
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'superadmin.delete_verse.warning'.tr(),
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'superadmin.delete_verse.cancel'.tr(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: const RoundedRectangleBorder(),
            side: const BorderSide(color: Colors.black, width: 3),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'superadmin.delete_verse.confirm'.tr(),
            style: AppTextStyles.buttonText.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String verseName,
    required VoidCallback onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteVerseConfirmationDialog(
        verseName: verseName,
        onConfirm: onConfirm,
      ),
    );
  }
}

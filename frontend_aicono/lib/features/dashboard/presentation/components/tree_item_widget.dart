import 'package:flutter/material.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_entity.dart';

class TreeItemWidget extends StatefulWidget {
  final TreeItemEntity item;
  final int level;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onExpandToggle;

  const TreeItemWidget({
    super.key,
    required this.item,
    this.level = 0,
    this.isExpanded = false,
    this.isSelected = false,
    this.onTap,
    this.onExpandToggle,
  });

  @override
  State<TreeItemWidget> createState() => _TreeItemWidgetState();
}

class _TreeItemWidgetState extends State<TreeItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSubItem = widget.level > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: EdgeInsets.only(
                left: isSubItem ? (widget.level * 8).toDouble() : 0,
                right: 16,
                top: 2,
                bottom: 2,
              ),
              decoration: BoxDecoration(
                color: _isHovered ? Colors.grey[50] : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    // Prefix for sub-items (=)
                    if (isSubItem)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '=',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),

                    // Item name with bold styling for selected
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: Colors.black87,
                          fontWeight: widget.isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Children count badge (optional)
                    if (widget.item.hasChildren)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.item.children.length}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

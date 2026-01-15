import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend_aicono/core/constant.dart';
import 'package:frontend_aicono/core/theme/app_theme.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_entity.dart';
import 'package:frontend_aicono/features/dashboard/presentation/components/tree_item_widget.dart';

class TreeViewWidget extends StatefulWidget {
  final List<TreeItemEntity> items;
  final Function(TreeItemEntity)? onItemTap;
  final VoidCallback? onAddItem;
  final String addItemLabel;

  const TreeViewWidget({
    super.key,
    required this.items,
    this.onItemTap,
    this.onAddItem,
    required this.addItemLabel,
  });

  @override
  State<TreeViewWidget> createState() => _TreeViewWidgetState();
}

class _TreeViewWidgetState extends State<TreeViewWidget> {
  final Set<String> _expandedItems = <String>{};
  String? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(0),
        child: Center(
          child: Text(
            'dashboard.tree_view.no_entries'.tr(),
            style: AppTextStyles.titleSmall.copyWith(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final List<Widget> tree = [..._buildRecursiveTreeItems(widget.items, 0)];

    // Add item link at the bottom
    if (widget.onAddItem != null) {
      tree.add(const SizedBox(height: 8));
      tree.add(_buildAddLink(widget.addItemLabel, widget.onAddItem!));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: tree);
  }

  List<Widget> _buildRecursiveTreeItems(List<TreeItemEntity> items, int level) {
    List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isExpanded = _expandedItems.contains(item.id);

      // Add the current item
      widgets.add(
        TreeItemWidget(
          item: item,
          level: level,
          isExpanded: isExpanded,
          isSelected: _selectedItemId == item.id,
          onTap: () => _handleItemTap(item),
          onExpandToggle: item.hasChildren
              ? () => _toggleExpansion(item.id)
              : null,
        ),
      );

      // Add separator line between items (except for the last item)
      if (i < items.length - 1) {
        widgets.add(
          const Divider(height: 8, thickness: 1, color: Color(0x40000000)),
        );
      }

      // Add children if expanded
      if (isExpanded && item.hasChildren) {
        widgets.addAll(_buildRecursiveTreeItems(item.children, level + 1));
      }
    }

    return widgets;
  }

  void _toggleExpansion(String itemId) {
    setState(() {
      if (_expandedItems.contains(itemId)) {
        _expandedItems.remove(itemId);
      } else {
        _expandedItems.add(itemId);
      }
    });
  }

  void _handleItemTap(TreeItemEntity item) {
    setState(() {
      _selectedItemId = item.id;
      // Toggle expansion on tap when there are children
      if (item.hasChildren) {
        if (_expandedItems.contains(item.id)) {
          _expandedItems.remove(item.id);
        } else {
          _expandedItems.add(item.id);
        }
      }
    });

    widget.onItemTap?.call(item);
  }

  Widget _buildAddLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

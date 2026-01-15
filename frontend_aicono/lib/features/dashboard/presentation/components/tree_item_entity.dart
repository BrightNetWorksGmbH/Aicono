/// Simple entity for tree items (Properties and Reportings)
class TreeItemEntity {
  final String id;
  final String name;
  final List<TreeItemEntity> children;
  final String type; // 'property' or 'reporting'

  TreeItemEntity({
    required this.id,
    required this.name,
    this.children = const [],
    required this.type,
  });

  bool get hasChildren => children.isNotEmpty;
}

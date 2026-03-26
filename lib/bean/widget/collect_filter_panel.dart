import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/collect_folder_selection_content.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

class CollectFilterPanel extends StatefulWidget {
  const CollectFilterPanel({
    super.key,
    required this.groups,
    required this.folders,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<CollectGroup> groups;
  final List<CollectFolder> folders;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  State<CollectFilterPanel> createState() => _CollectFilterPanelState();
}

class _CollectFilterPanelState extends State<CollectFilterPanel> {
  late Set<int> _pendingSelectedIds;

  Set<int> get _allIds => <int>{0, ...widget.folders.map((folder) => folder.id)};

  @override
  void initState() {
    super.initState();
    _pendingSelectedIds = Set<int>.from(widget.selectedIds);
  }

  @override
  void didUpdateWidget(covariant CollectFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIds != widget.selectedIds ||
        oldWidget.folders != widget.folders) {
      _pendingSelectedIds = Set<int>.from(widget.selectedIds);
    }
  }

  void _toggleId(int id) {
    setState(() {
      if (_pendingSelectedIds.contains(id)) {
        _pendingSelectedIds.remove(id);
      } else {
        _pendingSelectedIds.add(id);
      }
    });
    widget.onChanged(Set<int>.from(_pendingSelectedIds));
  }

  Widget _buildChip(BuildContext context, int id, String label) {
    final active = _pendingSelectedIds.contains(id);
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      backgroundColor:
          active ? colorScheme.surfaceContainer : colorScheme.errorContainer,
      side: active
          ? BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.35),
            )
          : BorderSide(
              color: colorScheme.error.withValues(alpha: 0.35),
            ),
      avatar: Icon(
        active ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: active ? colorScheme.primary : colorScheme.error,
      ),
      labelStyle: TextStyle(
        color:
            active ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
      ),
      label: Text(label),
      onPressed: () => _toggleId(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CollectFolderGroupedWrapContent(
      folders: widget.folders,
      groups: widget.groups,
      maxHeightFactor: 1,
      padding: EdgeInsets.zero,
      folderChipBuilder: (context, folder) =>
          _buildChip(context, folder.id, folder.name),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(context, 0, '未收藏'),
              ActionChip(
                avatar: const Icon(Icons.select_all, size: 16),
                label: const Text('全部收藏夹'),
                onPressed: () {
                  setState(() {
                    _pendingSelectedIds = Set<int>.from(_allIds);
                  });
                  widget.onChanged(Set<int>.from(_pendingSelectedIds));
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text('移除全部收藏夹'),
                onPressed: () {
                  setState(() {
                    _pendingSelectedIds = <int>{};
                  });
                  widget.onChanged(Set<int>.from(_pendingSelectedIds));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

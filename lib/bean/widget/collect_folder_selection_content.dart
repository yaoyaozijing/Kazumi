import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

class CollectFolderGroupedWrapContent extends StatelessWidget {
  const CollectFolderGroupedWrapContent({
    super.key,
    required this.folders,
    required this.groups,
    required this.folderChipBuilder,
    this.header,
    this.footer,
    this.maxHeightFactor = 0.82,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 12),
  });

  final List<CollectFolder> folders;
  final List<CollectGroup> groups;
  final Widget Function(BuildContext context, CollectFolder folder)
      folderChipBuilder;
  final Widget? header;
  final Widget? footer;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) header!,
              ...groups.map((group) {
                final groupFolders = folders
                    .where((folder) => folder.groupId == group.id)
                    .toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Expanded(
                            child: Divider(
                              height: 1,
                              indent: 8,
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groupFolders
                            .map((folder) => folderChipBuilder(context, folder))
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

class CollectFolderSelectionContent extends StatelessWidget {
  const CollectFolderSelectionContent({
    super.key,
    required this.folders,
    required this.groups,
    required this.folderChipBuilder,
    this.topActions,
    this.footer,
    this.title = '添加到收藏夹',
  });

  final List<CollectFolder> folders;
  final List<CollectGroup> groups;
  final Widget Function(BuildContext context, CollectFolder folder)
      folderChipBuilder;
  final Widget? topActions;
  final Widget? footer;
  final String title;

  @override
  Widget build(BuildContext context) {
    return CollectFolderGroupedWrapContent(
      folders: folders,
      groups: groups,
      folderChipBuilder: folderChipBuilder,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (topActions != null) topActions!,
          if (topActions != null) const SizedBox(height: 8),
          const SizedBox(height: 8),
        ],
      ),
      footer: footer,
    );
  }
}

class CollectFolderMultiSelectionSheet extends StatefulWidget {
  const CollectFolderMultiSelectionSheet({
    super.key,
    required this.collectController,
    required this.items,
    required this.folders,
    required this.groups,
    this.onApplied,
    this.onStateChanged,
    this.title = '添加到收藏夹',
    this.showRemoveAllButton = true,
  });

  final CollectController collectController;
  final List<BangumiItem> items;
  final List<CollectFolder> folders;
  final List<CollectGroup> groups;
  final VoidCallback? onApplied;
  final VoidCallback? onStateChanged;
  final String title;
  final bool showRemoveAllButton;

  @override
  State<CollectFolderMultiSelectionSheet> createState() =>
      _CollectFolderMultiSelectionSheetState();
}

class _CollectFolderMultiSelectionSheetState
    extends State<CollectFolderMultiSelectionSheet> {
  Set<int> get _allFolderIds => widget.folders.map((e) => e.id).toSet();

  int _selectedCountForFolder(int folderId) {
    int hasCount = 0;
    for (final item in widget.items) {
      final types = widget.collectController.getCollectTypes(item);
      if (types.contains(folderId)) {
        hasCount++;
      }
    }
    return hasCount;
  }

  void _toggleFolderBySelectionState(CollectFolder folder) {
    final hasCount = _selectedCountForFolder(folder.id);
    final allSelected = hasCount == widget.items.length;
    KazumiDialog.showLoading(msg: '处理中');
    Future<void>(() async {
      for (final item in widget.items) {
        final types = widget.collectController.getCollectTypes(item);
        final hasType = types.contains(folder.id);
        if (allSelected && hasType) {
          await widget.collectController.toggleCollectType(item, folder.id);
        } else if (!allSelected && !hasType) {
          await widget.collectController.toggleCollectType(item, folder.id);
        }
      }
    }).whenComplete(() {
      KazumiDialog.dismiss();
      widget.onApplied?.call();
      widget.onStateChanged?.call();
      if (mounted) setState(() {});
    });
  }

  void _selectAllFolders() {
    KazumiDialog.showLoading(msg: '处理中');
    Future<void>(() async {
      for (final item in widget.items) {
        final types = widget.collectController.getCollectTypes(item);
        for (final folderId in _allFolderIds) {
          if (!types.contains(folderId)) {
            await widget.collectController.toggleCollectType(item, folderId);
          }
        }
      }
    }).whenComplete(() {
      KazumiDialog.dismiss();
      widget.onApplied?.call();
      widget.onStateChanged?.call();
      if (mounted) setState(() {});
    });
  }

  void _clearAllFolders() {
    KazumiDialog.showLoading(msg: '处理中');
    Future<void>(() async {
      for (final item in widget.items) {
        final types = widget.collectController.getCollectTypes(item);
        if (types.isNotEmpty) {
          await widget.collectController.deleteCollect(item);
        }
      }
    }).whenComplete(() {
      KazumiDialog.dismiss();
      widget.onApplied?.call();
      widget.onStateChanged?.call();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return CollectFolderSelectionContent(
      folders: widget.folders,
      groups: widget.groups,
      title: widget.title,
      topActions: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.select_all, size: 16),
            label: const Text('全部收藏夹'),
            onPressed: _selectAllFolders,
          ),
          ActionChip(
            avatar: const Icon(Icons.remove_circle_outline, size: 16),
            label: const Text('移除全部收藏夹'),
            onPressed: _clearAllFolders,
          ),
        ],
      ),
      folderChipBuilder: (context, folder) {
        final hasCount = _selectedCountForFolder(folder.id);
        final allSelected = hasCount == widget.items.length;
        final partiallySelected = hasCount > 0 && hasCount < widget.items.length;
        return ActionChip(
          avatar: Icon(
            allSelected
                ? Icons.check_circle
                : partiallySelected
                    ? Icons.remove_circle
                    : Icons.add_circle_outline,
            size: 16,
            color: allSelected || partiallySelected
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          label: Text(folder.name),
          onPressed: () {
            _toggleFolderBySelectionState(folder);
          },
        );
      },
    );
  }
}

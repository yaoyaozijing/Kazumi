import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

class CollectManagerSheet extends StatefulWidget {
  const CollectManagerSheet({
    super.key,
    required this.collectController,
    required this.hideBuiltInCollectFolders,
    this.defaultCollectGroupId = 0,
  });

  final CollectController collectController;
  final bool hideBuiltInCollectFolders;
  final int defaultCollectGroupId;

  @override
  State<CollectManagerSheet> createState() => _CollectManagerSheetState();
}

class _CollectManagerSheetState extends State<CollectManagerSheet> {
  final List<CollectFolder> dialogFolders = <CollectFolder>[];
  final List<CollectGroup> dialogGroups = <CollectGroup>[];
  final Map<int, TextEditingController> groupNameControllers =
      <int, TextEditingController>{};
  final Set<int> editingGroupIds = <int>{};

  List<CollectFolder> get visibleCollectFolders =>
      widget.hideBuiltInCollectFolders
          ? widget.collectController
              .getCollectFolders()
              .where((folder) => !folder.isBuiltIn)
              .toList()
          : widget.collectController.getCollectFolders();

  @override
  void initState() {
    super.initState();
    refreshView();
  }

  @override
  void dispose() {
    for (final controller in groupNameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController controllerForGroup(CollectGroup group) {
    final controller = groupNameControllers.putIfAbsent(
      group.id,
      () => TextEditingController(text: group.name),
    );
    if (!editingGroupIds.contains(group.id) && controller.text != group.name) {
      controller.text = group.name;
    }
    return controller;
  }

  Future<void> refreshView() async {
    dialogFolders
      ..clear()
      ..addAll(visibleCollectFolders);
    dialogGroups
      ..clear()
      ..addAll(widget.collectController.getCollectGroups());
    if (!mounted) return;
    setState(() {});
  }

  Future<void> moveFolderAndPersist({
    required CollectFolder dragged,
    required int toGroupId,
    required int insertIndex,
  }) async {
    if (dragged.isBuiltIn) return;
    final fromIndex =
        dialogFolders.indexWhere((folder) => folder.id == dragged.id);
    if (fromIndex == -1) return;

    final moveError =
        await widget.collectController.moveFolderToGroup(dragged.id, toGroupId);
    if (moveError != null) {
      if (mounted) KazumiDialog.showToast(message: moveError);
      return;
    }

    final moved = CollectFolder(
      id: dragged.id,
      name: dragged.name,
      groupId: toGroupId,
    );
    dialogFolders.removeAt(fromIndex);
    final normalizedIndex = insertIndex.clamp(0, dialogFolders.length);
    dialogFolders.insert(normalizedIndex, moved);
    await widget.collectController.updateCollectFolderOrder(dialogFolders);
    await refreshView();
  }

  Future<void> showCollectGroupCreateDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '分组名称',
          ),
          onSubmitted: (_) async {
            final error = await widget.collectController
                .createCustomCollectGroup(controller.text);
            if (!context.mounted) return;
            if (error != null) {
              KazumiDialog.showToast(message: error);
              return;
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final error = await widget.collectController
                  .createCustomCollectGroup(controller.text);
              if (!context.mounted) return;
              if (error != null) {
                KazumiDialog.showToast(message: error);
                return;
              }
              Navigator.of(context).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> showCollectFolderActionDialog(CollectFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    int selectedGroupId = folder.groupId;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑收藏夹'),
          content: folder.isBuiltIn
              ? const Text('默认收藏夹不支持编辑和删除')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '收藏夹名称',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey<int>(selectedGroupId),
                      initialValue: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: '所属分组',
                      ),
                      items: widget.collectController
                          .getCollectGroups()
                          .map((group) => DropdownMenuItem<int>(
                                value: group.id,
                                child: Text(group.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedGroupId = value;
                        });
                      },
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                folder.isBuiltIn ? '关闭' : '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            if (!folder.isBuiltIn)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await showCollectFolderDeleteDialog(folder);
                },
                child: const Text('删除'),
              ),
            if (!folder.isBuiltIn)
              TextButton(
                onPressed: () async {
                  final renameError =
                      await widget.collectController.renameCustomCollectFolder(
                    folder.id,
                    controller.text,
                  );
                  if (renameError != null) {
                    if (context.mounted) {
                      KazumiDialog.showToast(message: renameError);
                    }
                    return;
                  }
                  final moveError =
                      await widget.collectController.moveFolderToGroup(
                    folder.id,
                    selectedGroupId,
                  );
                  if (moveError != null) {
                    if (context.mounted) {
                      KazumiDialog.showToast(message: moveError);
                    }
                    return;
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('保存'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showCollectFolderCreateDialog({int? groupId}) async {
    final targetGroupId = groupId ?? widget.defaultCollectGroupId;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            '新增收藏夹（${widget.collectController.getCollectGroupName(targetGroupId)}）'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '收藏夹名称',
            hintText: '输入名称',
          ),
          onSubmitted: (_) async {
            final error =
                await widget.collectController.createCustomCollectFolder(
              controller.text,
              groupId: targetGroupId,
            );
            if (!context.mounted) return;
            if (error != null) {
              KazumiDialog.showToast(message: error);
              return;
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final error =
                  await widget.collectController.createCustomCollectFolder(
                controller.text,
                groupId: targetGroupId,
              );
              if (!context.mounted) return;
              if (error != null) {
                KazumiDialog.showToast(message: error);
                return;
              }
              Navigator.of(context).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<bool> showCollectFolderDeleteDialog(CollectFolder folder) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: Text('确认删除「${folder.name}」吗？\n已加入该收藏夹的番剧会移除此标签。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final error =
                  await widget.collectController.deleteCustomCollectFolder(
                folder.id,
              );
              if (!context.mounted) return;
              if (error != null) {
                KazumiDialog.showToast(message: error);
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '管理收藏夹',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: dialogGroups.length,
                onReorder: (oldIndex, newIndex) async {
                  final normalizedNewIndex =
                      newIndex > oldIndex ? newIndex - 1 : newIndex;
                  final moved = dialogGroups.removeAt(oldIndex);
                  dialogGroups.insert(normalizedNewIndex, moved);
                  setState(() {});
                  await widget.collectController.updateCollectGroupOrder(
                    dialogGroups,
                  );
                  await refreshView();
                },
                itemBuilder: (context, groupIndex) {
                  final group = dialogGroups[groupIndex];
                  final groupFolders = dialogFolders
                      .where((folder) => folder.groupId == group.id)
                      .toList();
                  final builtInCountInDefault = group.id ==
                          widget.defaultCollectGroupId
                      ? groupFolders.where((folder) => folder.isBuiltIn).length
                      : 0;
                  return Padding(
                    key: ValueKey<int>(group.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ReorderableDragStartListener(
                              index: groupIndex,
                              child: Icon(
                                Icons.drag_indicator,
                                size: 18,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (group.isBuiltIn) ...[
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                            ] else if (editingGroupIds.contains(group.id)) ...[
                              Expanded(
                                child: TextField(
                                  controller: controllerForGroup(group),
                                  autofocus: true,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    hintText: '分组名称',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) async {
                                    final error = await widget.collectController
                                        .renameCustomCollectGroup(
                                      group.id,
                                      controllerForGroup(group).text,
                                    );
                                    if (error != null) {
                                      KazumiDialog.showToast(message: error);
                                      return;
                                    }
                                    editingGroupIds.remove(group.id);
                                    if (mounted) {
                                      await refreshView();
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                tooltip: '确认重命名',
                                onPressed: () async {
                                  final error = await widget.collectController
                                      .renameCustomCollectGroup(
                                    group.id,
                                    controllerForGroup(group).text,
                                  );
                                  if (error != null) {
                                    KazumiDialog.showToast(message: error);
                                    return;
                                  }
                                  editingGroupIds.remove(group.id);
                                  if (mounted) {
                                    await refreshView();
                                  }
                                },
                                icon: const Icon(Icons.check),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                tooltip: '删除分组',
                                onPressed: () async {
                                  await widget.collectController
                                      .deleteCustomCollectGroup(group.id);
                                  if (mounted) {
                                    await refreshView();
                                  }
                                },
                                color: Theme.of(context).colorScheme.error,
                                icon: const Icon(Icons.delete_outline),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                            ] else ...[
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                tooltip: '编辑分组',
                                onPressed: () {
                                  controllerForGroup(group).text = group.name;
                                  setState(() {
                                    editingGroupIds.add(group.id);
                                  });
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        DragTarget<CollectFolder>(
                          onWillAcceptWithDetails: (details) =>
                              !details.data.isBuiltIn,
                          onAcceptWithDetails: (details) async {
                            final dragged = details.data;
                            final toInsertAt =
                                group.id == widget.defaultCollectGroupId
                                    ? dialogFolders.indexWhere((folder) =>
                                        folder.groupId ==
                                            widget.defaultCollectGroupId &&
                                        !folder.isBuiltIn)
                                    : dialogFolders.lastIndexWhere((folder) =>
                                            folder.groupId == group.id) +
                                        1;
                            final safeInsertIndex = toInsertAt == -1
                                ? dialogFolders.length
                                : toInsertAt;
                            await moveFolderAndPersist(
                              dragged: dragged,
                              toGroupId: group.id,
                              insertIndex: safeInsertIndex,
                            );
                          },
                          builder: (context, _, __) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...groupFolders.map((folder) {
                                  return DragTarget<CollectFolder>(
                                    onWillAcceptWithDetails: (details) {
                                      final dragged = details.data;
                                      if (dragged.isBuiltIn) {
                                        return false;
                                      }
                                      if (group.id ==
                                              widget.defaultCollectGroupId &&
                                          folder.isBuiltIn) {
                                        return false;
                                      }
                                      return true;
                                    },
                                    onAcceptWithDetails: (details) async {
                                      final dragged = details.data;
                                      final targetGlobalIndex =
                                          dialogFolders.indexWhere(
                                        (f) => f.id == folder.id,
                                      );
                                      if (targetGlobalIndex == -1) {
                                        return;
                                      }
                                      var insertIndex = targetGlobalIndex;
                                      if (group.id ==
                                              widget.defaultCollectGroupId &&
                                          insertIndex < builtInCountInDefault) {
                                        insertIndex = builtInCountInDefault;
                                      }
                                      await moveFolderAndPersist(
                                        dragged: dragged,
                                        toGroupId: group.id,
                                        insertIndex: insertIndex,
                                      );
                                    },
                                    builder: (context, _, __) {
                                      final chip = ActionChip(
                                        avatar: folder.isBuiltIn
                                            ? const Icon(
                                                Icons.lock_outline,
                                                size: 16,
                                              )
                                            : const Icon(
                                                Icons.drag_indicator,
                                                size: 16,
                                              ),
                                        label: Text(folder.name),
                                        onPressed: () async {
                                          await showCollectFolderActionDialog(
                                            folder,
                                          );
                                          if (mounted) {
                                            await refreshView();
                                          }
                                        },
                                      );
                                      if (folder.isBuiltIn) {
                                        return chip;
                                      }
                                      return LongPressDraggable<CollectFolder>(
                                        data: folder,
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: ActionChip(
                                            avatar: const Icon(
                                              Icons.drag_indicator,
                                              size: 16,
                                            ),
                                            label: Text(folder.name),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.45,
                                          child: chip,
                                        ),
                                        child: chip,
                                      );
                                    },
                                  );
                                }),
                                ActionChip(
                                  avatar: const Icon(Icons.add, size: 16),
                                  label: const Text('新建收藏夹'),
                                  onPressed: () async {
                                    await showCollectFolderCreateDialog(
                                      groupId: group.id,
                                    );
                                    if (mounted) {
                                      await refreshView();
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await showCollectGroupCreateDialog();
                      if (mounted) await refreshView();
                    },
                    icon: const Icon(Icons.create_new_folder, size: 16),
                    label: const Text('新建分组'),
                  ),
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

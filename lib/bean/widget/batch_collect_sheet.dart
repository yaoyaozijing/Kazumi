import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_folder_selection_content.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/utils/storage.dart';

class BatchCollectSheet {
  BatchCollectSheet._();

  static Future<void> show({
    required BuildContext context,
    required List<BangumiItem> items,
    required String keyword,
    int defaultGroupId = 0,
    VoidCallback? onApplied,
  }) async {
    final collectController = Modular.get<CollectController>();
    final uniqueItems = _dedupe(items);
    if (uniqueItems.isEmpty) {
      KazumiDialog.showToast(message: '当前没有可保存的搜索结果');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: 290,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '批量添加到收藏夹',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flash_on_outlined),
                  title: const Text('快速新建并保存'),
                  subtitle: Text(
                    '直接用“${keyword.trim()}”作为收藏夹名',
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _quickCreateFolderFromKeyword(
                      context: context,
                      collectController: collectController,
                      items: uniqueItems,
                      keyword: keyword,
                      defaultGroupId: defaultGroupId,
                      onApplied: onApplied,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text('保存为新收藏夹'),
                  subtitle: Text('共 ${uniqueItems.length} 条结果'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showCreateFolderDialog(
                      context: context,
                      collectController: collectController,
                      items: uniqueItems,
                      defaultName: keyword.trim(),
                      defaultGroupId: defaultGroupId,
                      onApplied: onApplied,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('添加到已有收藏夹'),
                  subtitle: Text('共 ${uniqueItems.length} 条结果'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showAddToFolderSheet(
                      context: context,
                      collectController: collectController,
                      items: uniqueItems,
                      onApplied: onApplied,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static List<BangumiItem> _dedupe(List<BangumiItem> rawItems) {
    final uniqueItems = <int, BangumiItem>{};
    for (final item in rawItems) {
      uniqueItems[item.id] = item;
    }
    return uniqueItems.values.toList();
  }

  static Future<void> _quickCreateFolderFromKeyword({
    required BuildContext context,
    required CollectController collectController,
    required List<BangumiItem> items,
    required String keyword,
    required int defaultGroupId,
    VoidCallback? onApplied,
  }) async {
    final name = keyword.trim();
    if (name.isEmpty) {
      KazumiDialog.showToast(message: '搜索词为空，无法快速新建收藏夹');
      return;
    }
    final error = await collectController.createCustomCollectFolder(
      name,
      groupId: defaultGroupId,
    );
    final created = _findFolderByName(collectController, name);
    if (error != null && created == null) {
      KazumiDialog.showToast(message: error);
      return;
    }
    if (created == null) {
      KazumiDialog.showToast(message: '收藏夹创建成功，但未找到该收藏夹');
      return;
    }
    await _addItemsToFolder(
      collectController: collectController,
      items: items,
      folderId: created.id,
      onApplied: onApplied,
    );
  }

  static Future<void> _showCreateFolderDialog({
    required BuildContext context,
    required CollectController collectController,
    required List<BangumiItem> items,
    required String defaultName,
    required int defaultGroupId,
    VoidCallback? onApplied,
  }) async {
    final controller = TextEditingController(text: defaultName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建收藏夹并保存'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '收藏夹名称',
            hintText: '输入名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.outline,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              final error = await collectController.createCustomCollectFolder(
                name,
                groupId: defaultGroupId,
              );
              if (!dialogContext.mounted) return;
              if (error != null) {
                KazumiDialog.showToast(message: error);
                return;
              }
              final created = _findFolderByName(collectController, name);
              Navigator.of(dialogContext).pop();
              if (created == null) {
                KazumiDialog.showToast(message: '收藏夹创建成功，但未找到该收藏夹');
                return;
              }
              await _addItemsToFolder(
                collectController: collectController,
                items: items,
                folderId: created.id,
                onApplied: onApplied,
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showAddToFolderSheet({
    required BuildContext context,
    required CollectController collectController,
    required List<BangumiItem> items,
    VoidCallback? onApplied,
  }) async {
    final hideBuiltInFolders = GStorage.setting.get(
          SettingBoxKey.collectHideBuiltInFolders,
          defaultValue: false,
        ) ==
        true;
    final folders = hideBuiltInFolders
        ? collectController
            .getCollectFolders()
            .where((folder) => !folder.isBuiltIn)
            .toList()
        : collectController.getCollectFolders();
    final groups = collectController.getCollectGroups();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return CollectFolderMultiSelectionSheet(
          collectController: collectController,
          items: items,
          folders: folders,
          groups: groups,
          onApplied: onApplied,
        );
      },
    );
  }

  static CollectFolder? _findFolderByName(
    CollectController collectController,
    String name,
  ) {
    for (final folder in collectController.getCollectFolders()) {
      if (folder.name == name) return folder;
    }
    return null;
  }

  static Future<void> _addItemsToFolder({
    required CollectController collectController,
    required List<BangumiItem> items,
    required int folderId,
    VoidCallback? onApplied,
  }) async {
    if (items.isEmpty) {
      KazumiDialog.showToast(message: '没有可保存的结果');
      return;
    }
    int addedCount = 0;
    KazumiDialog.showLoading(msg: '保存中');
    try {
      for (final item in items) {
        final currentTypes = collectController.getCollectTypes(item);
        if (currentTypes.contains(folderId)) continue;
        await collectController.toggleCollectType(item, folderId);
        addedCount++;
      }
    } finally {
      KazumiDialog.dismiss();
    }

    final folderName = collectController.getCollectFolderName(folderId);
    KazumiDialog.showToast(
      message: addedCount > 0
          ? '已添加 $addedCount 条到「$folderName」'
          : '结果已存在于「$folderName」',
    );
    onApplied?.call();
  }
}

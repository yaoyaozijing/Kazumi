import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/widget/collect_folder_selection_content.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/storage.dart';

class CollectButton extends StatefulWidget {
  CollectButton({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = false;
  }

  CollectButton.extend({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;

  @override
  State<CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends State<CollectButton> {
  late List<int> collectTypes;
  final CollectController collectController = Modular.get<CollectController>();

  @override
  void initState() {
    super.initState();
  }

  Future<void> openCollectBottomSheet() async {
    widget.onOpen?.call();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
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
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedTypes =
                collectController.getCollectTypes(widget.bangumiItem);
            return CollectFolderSelectionContent(
              folders: folders,
              groups: groups,
              topActions: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.select_all, size: 16),
                    label: const Text('全部收藏夹'),
                    onPressed: () async {
                      for (final folder in folders) {
                        if (!selectedTypes.contains(folder.id)) {
                          await collectController.toggleCollectType(
                              widget.bangumiItem, folder.id);
                        }
                      }
                      if (!mounted) return;
                      setState(() {});
                      setSheetState(() {});
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('移除全部收藏夹'),
                    onPressed: () async {
                      if (selectedTypes.isNotEmpty) {
                        await collectController.deleteCollect(widget.bangumiItem);
                      }
                      if (!mounted) return;
                      setState(() {});
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
              folderChipBuilder: (context, folder) {
                final active = selectedTypes.contains(folder.id);
                return ActionChip(
                  avatar: Icon(
                    active ? Icons.check_circle : Icons.add_circle_outline,
                    size: 16,
                    color: active ? Theme.of(context).colorScheme.primary : null,
                  ),
                  label: Text(folder.name),
                  onPressed: () async {
                    await collectController.toggleCollectType(
                        widget.bangumiItem, folder.id);
                    if (!mounted) return;
                    setState(() {});
                    setSheetState(() {});
                  },
                );
              },
            );
          },
        );
      },
    );
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    collectTypes = collectController.getCollectTypes(widget.bangumiItem);
    if (widget.isExtended) {
      return FilledButton.icon(
        onPressed: openCollectBottomSheet,
        icon: const Icon(Icons.favorite),
        label: Text(
          collectTypes.length > 1
              ? '${collectTypes.length}个收藏夹'
              : collectController.getCollectFolderName(
                  collectTypes.isEmpty ? 0 : collectTypes.first),
        ),
      );
    }
    return IconButton(
      onPressed: openCollectBottomSheet,
      icon: Icon(
        Icons.favorite,
        color: widget.color,
      ),
    );
  }
}

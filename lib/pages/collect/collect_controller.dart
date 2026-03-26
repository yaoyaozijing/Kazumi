import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';

part 'collect_controller.g.dart';

class CollectFolder {
  const CollectFolder({
    required this.id,
    required this.name,
    required this.groupId,
    this.isBuiltIn = false,
  });

  final int id;
  final String name;
  final int groupId;
  final bool isBuiltIn;
}

class CollectGroup {
  const CollectGroup({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
  });

  final int id;
  final String name;
  final bool isBuiltIn;
}

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  final _collectCrudRepository = Modular.get<ICollectCrudRepository>();

  Box setting = GStorage.setting;
  List<BangumiItem> get favorites => _collectCrudRepository.getFavorites();

  @observable
  ObservableList<CollectedBangumi> collectibles =
      ObservableList<CollectedBangumi>();

  static const Map<int, String> _builtInCollectFolders = <int, String>{
    1: '在看',
    2: '想看',
    3: '搁置',
    4: '看过',
    5: '抛弃',
  };
  static const int defaultCollectGroupId = 0;
  static const String defaultCollectGroupName = '默认分组';

  void loadCollectibles() {
    collectibles.clear();
    collectibles.addAll(_collectCrudRepository.getAllCollectibles());
  }

  List<CollectFolder> getCollectFolders() {
    final folders = <CollectFolder>[
      for (final entry in _builtInCollectFolders.entries)
        CollectFolder(
          id: entry.key,
          name: entry.value,
          groupId: defaultCollectGroupId,
          isBuiltIn: true,
        ),
      ..._loadCustomCollectFolders(),
    ];
    final order = _loadCollectFolderOrder();
    if (order.isEmpty) {
      folders.sort((a, b) => a.id.compareTo(b.id));
      return folders;
    }
    final folderMap = {for (final folder in folders) folder.id: folder};
    final ordered = <CollectFolder>[];
    for (final id in order) {
      final folder = folderMap.remove(id);
      if (folder != null) {
        ordered.add(folder);
      }
    }
    final remaining = folderMap.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    ordered.addAll(remaining);
    final builtIn = ordered.where((folder) => folder.isBuiltIn).toList();
    final others = ordered.where((folder) => !folder.isBuiltIn).toList();
    return <CollectFolder>[...builtIn, ...others];
  }

  List<CollectGroup> getCollectGroups() {
    final groups = <CollectGroup>[
      const CollectGroup(
        id: defaultCollectGroupId,
        name: defaultCollectGroupName,
        isBuiltIn: true,
      ),
      ..._loadCustomCollectGroups(),
    ];
    final order = _loadCollectGroupOrder();
    if (order.isEmpty) {
      groups.sort((a, b) => a.id.compareTo(b.id));
      return groups;
    }
    final groupMap = {for (final group in groups) group.id: group};
    final ordered = <CollectGroup>[];
    for (final id in order) {
      final group = groupMap.remove(id);
      if (group != null) {
        ordered.add(group);
      }
    }
    final remaining = groupMap.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    ordered.addAll(remaining);
    return ordered;
  }

  String getCollectGroupName(int groupId) {
    if (groupId == defaultCollectGroupId) {
      return defaultCollectGroupName;
    }
    for (final group in _loadCustomCollectGroups()) {
      if (group.id == groupId) return group.name;
    }
    return '分组$groupId';
  }

  Future<String?> createCustomCollectGroup(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return '分组名称不能为空';
    final groups = getCollectGroups();
    if (groups.any((group) => group.name == name)) {
      return '分组名称已存在';
    }
    final customGroups = _loadCustomCollectGroups();
    final maxId = groups.fold<int>(defaultCollectGroupId, (max, group) {
      return group.id > max ? group.id : max;
    });
    customGroups.add(CollectGroup(id: maxId + 1, name: name));
    await _saveCustomCollectGroups(customGroups);
    final order = _loadCollectGroupOrder();
    if (!order.contains(maxId + 1)) {
      order.add(maxId + 1);
      await _saveCollectGroupOrder(order);
    }
    return null;
  }

  Future<String?> renameCustomCollectGroup(int groupId, String rawName) async {
    if (groupId == defaultCollectGroupId) {
      return '默认分组不支持重命名';
    }
    final name = rawName.trim();
    if (name.isEmpty) return '分组名称不能为空';
    final groups = getCollectGroups();
    if (groups.any((group) => group.id != groupId && group.name == name)) {
      return '分组名称已存在';
    }
    final customGroups = _loadCustomCollectGroups();
    final index = customGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) return '分组不存在';
    customGroups[index] = CollectGroup(id: groupId, name: name);
    await _saveCustomCollectGroups(customGroups);
    return null;
  }

  Future<String?> deleteCustomCollectGroup(int groupId) async {
    if (groupId == defaultCollectGroupId) {
      return '默认分组不支持删除';
    }
    final customGroups = _loadCustomCollectGroups();
    final nextGroups =
        customGroups.where((group) => group.id != groupId).toList();
    if (nextGroups.length == customGroups.length) return '分组不存在';
    await _saveCustomCollectGroups(nextGroups);
    final order = _loadCollectGroupOrder()..removeWhere((id) => id == groupId);
    await _saveCollectGroupOrder(order);

    final customFolders = _loadCustomCollectFolders()
        .map((folder) => folder.groupId == groupId
            ? CollectFolder(
                id: folder.id,
                name: folder.name,
                groupId: defaultCollectGroupId,
                isBuiltIn: false,
              )
            : folder)
        .toList();
    await _saveCustomCollectFolders(customFolders);
    return null;
  }

  Future<void> updateCollectGroupOrder(List<CollectGroup> groups) async {
    await _saveCollectGroupOrder(groups.map((e) => e.id).toList());
  }

  Future<void> reorderCollectFolders(int oldIndex, int newIndex) async {
    final folders = getCollectFolders();
    if (oldIndex < 0 || oldIndex >= folders.length) return;
    if (newIndex < 0 || newIndex > folders.length) return;
    final normalizedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (normalizedNewIndex == oldIndex) return;
    final moved = folders.removeAt(oldIndex);
    folders.insert(normalizedNewIndex, moved);
    await _saveCollectFolderOrder(folders.map((e) => e.id).toList());
  }

  Future<void> updateCollectFolderOrder(List<CollectFolder> folders) async {
    await _saveCollectFolderOrder(folders.map((e) => e.id).toList());
  }

  String getCollectFolderName(int folderId) {
    if (folderId == 0) return '未收藏';
    if (_builtInCollectFolders.containsKey(folderId)) {
      return _builtInCollectFolders[folderId]!;
    }
    for (final folder in _loadCustomCollectFolders()) {
      if (folder.id == folderId) return folder.name;
    }
    return '收藏夹$folderId';
  }

  bool isBuiltInCollectFolder(int folderId) =>
      _builtInCollectFolders.containsKey(folderId);

  Future<String?> createCustomCollectFolder(String rawName,
      {int groupId = defaultCollectGroupId}) async {
    final name = rawName.trim();
    if (name.isEmpty) return '收藏夹名称不能为空';
    final allFolders = getCollectFolders();
    if (allFolders.any((folder) => folder.name == name)) {
      return '收藏夹名称已存在';
    }
    final customFolders = _loadCustomCollectFolders();
    final maxId = allFolders.fold<int>(0, (max, folder) {
      return folder.id > max ? folder.id : max;
    });
    final newFolder = CollectFolder(
      id: maxId + 1,
      name: name,
      groupId: groupId,
      isBuiltIn: false,
    );
    customFolders.add(newFolder);
    await _saveCustomCollectFolders(customFolders);
    final order = _loadCollectFolderOrder();
    if (!order.contains(newFolder.id)) {
      order.add(newFolder.id);
      await _saveCollectFolderOrder(order);
    }
    return null;
  }

  Future<String?> renameCustomCollectFolder(
      int folderId, String rawName) async {
    if (isBuiltInCollectFolder(folderId)) {
      return '默认收藏夹不支持重命名';
    }
    final name = rawName.trim();
    if (name.isEmpty) return '收藏夹名称不能为空';
    final allFolders = getCollectFolders();
    if (allFolders
        .any((folder) => folder.id != folderId && folder.name == name)) {
      return '收藏夹名称已存在';
    }
    final customFolders = _loadCustomCollectFolders();
    final index = customFolders.indexWhere((folder) => folder.id == folderId);
    if (index == -1) return '收藏夹不存在';
    customFolders[index] = CollectFolder(
      id: folderId,
      name: name,
      groupId: customFolders[index].groupId,
    );
    await _saveCustomCollectFolders(customFolders);
    return null;
  }

  Future<String?> moveFolderToGroup(int folderId, int groupId) async {
    if (isBuiltInCollectFolder(folderId)) return '默认收藏夹不能移动分组';
    final groups = getCollectGroups();
    if (!groups.any((g) => g.id == groupId)) return '分组不存在';
    final customFolders = _loadCustomCollectFolders();
    final index = customFolders.indexWhere((folder) => folder.id == folderId);
    if (index == -1) return '收藏夹不存在';
    final folder = customFolders[index];
    customFolders[index] = CollectFolder(
      id: folder.id,
      name: folder.name,
      groupId: groupId,
      isBuiltIn: false,
    );
    await _saveCustomCollectFolders(customFolders);
    return null;
  }

  Future<String?> deleteCustomCollectFolder(int folderId) async {
    if (isBuiltInCollectFolder(folderId)) {
      return '默认收藏夹不支持删除';
    }
    final customFolders = _loadCustomCollectFolders();
    final nextCustomFolders =
        customFolders.where((folder) => folder.id != folderId).toList();
    if (nextCustomFolders.length == customFolders.length) {
      return '收藏夹不存在';
    }
    await _saveCustomCollectFolders(nextCustomFolders);
    final order = _loadCollectFolderOrder()
      ..removeWhere((id) => id == folderId);
    await _saveCollectFolderOrder(order);
    await _collectCrudRepository.removeCollectTypeFromAll(folderId);
    await _recordCollectChange(0, 2, folderId);
    loadCollectibles();
    return null;
  }

  List<CollectFolder> _loadCustomCollectFolders() {
    final dynamic rawValue = setting
        .get(SettingBoxKey.collectCustomFolders, defaultValue: <dynamic>[]);
    if (rawValue is! List) return <CollectFolder>[];
    final validGroupIds = <int>{
      defaultCollectGroupId,
      ..._loadCustomCollectGroups().map((g) => g.id),
    };
    final folders = <CollectFolder>[];
    for (final item in rawValue) {
      if (item is! Map) continue;
      final idValue = item['id'];
      final nameValue = item['name'];
      final groupIdValue = item['groupId'];
      if (idValue is! int || idValue < 1) continue;
      if (nameValue is! String || nameValue.trim().isEmpty) continue;
      if (_builtInCollectFolders.containsKey(idValue)) continue;
      folders.add(CollectFolder(
        id: idValue,
        name: nameValue.trim(),
        groupId: groupIdValue is int &&
                groupIdValue >= 0 &&
                validGroupIds.contains(groupIdValue)
            ? groupIdValue
            : defaultCollectGroupId,
      ));
    }
    final deduped = <int, CollectFolder>{};
    for (final folder in folders) {
      deduped[folder.id] = folder;
    }
    return deduped.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _saveCustomCollectFolders(List<CollectFolder> folders) async {
    final raw = folders
        .where((folder) => !folder.isBuiltIn)
        .map((folder) => <String, dynamic>{
              'id': folder.id,
              'name': folder.name,
              'groupId': folder.groupId,
            })
        .toList();
    await setting.put(SettingBoxKey.collectCustomFolders, raw);
  }

  List<CollectGroup> _loadCustomCollectGroups() {
    final dynamic rawValue = setting
        .get(SettingBoxKey.collectCustomGroups, defaultValue: <dynamic>[]);
    if (rawValue is! List) return <CollectGroup>[];
    final groups = <CollectGroup>[];
    for (final item in rawValue) {
      if (item is! Map) continue;
      final idValue = item['id'];
      final nameValue = item['name'];
      if (idValue is! int || idValue <= defaultCollectGroupId) continue;
      if (nameValue is! String || nameValue.trim().isEmpty) continue;
      groups.add(CollectGroup(id: idValue, name: nameValue.trim()));
    }
    final deduped = <int, CollectGroup>{};
    for (final group in groups) {
      deduped[group.id] = group;
    }
    return deduped.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _saveCustomCollectGroups(List<CollectGroup> groups) async {
    final raw = groups
        .where((group) => !group.isBuiltIn)
        .map((group) => <String, dynamic>{
              'id': group.id,
              'name': group.name,
            })
        .toList();
    await setting.put(SettingBoxKey.collectCustomGroups, raw);
  }

  List<int> _loadCollectGroupOrder() {
    final dynamic rawValue =
        setting.get(SettingBoxKey.collectGroupOrder, defaultValue: <dynamic>[]);
    if (rawValue is! List) return <int>[];
    final order = <int>[];
    final seen = <int>{};
    for (final item in rawValue) {
      if (item is! int || item < defaultCollectGroupId) continue;
      if (seen.add(item)) {
        order.add(item);
      }
    }
    return order;
  }

  Future<void> _saveCollectGroupOrder(List<int> order) async {
    final seen = <int>{};
    final normalized = <int>[];
    for (final id in order) {
      if (id < defaultCollectGroupId) continue;
      if (seen.add(id)) {
        normalized.add(id);
      }
    }
    await setting.put(SettingBoxKey.collectGroupOrder, normalized);
  }

  List<int> _loadCollectFolderOrder() {
    final dynamic rawValue = setting
        .get(SettingBoxKey.collectFolderOrder, defaultValue: <dynamic>[]);
    if (rawValue is! List) return <int>[];
    final order = <int>[];
    final seen = <int>{};
    for (final item in rawValue) {
      if (item is! int || item < 1) continue;
      if (seen.add(item)) {
        order.add(item);
      }
    }
    return order;
  }

  Future<void> _saveCollectFolderOrder(List<int> order) async {
    final seen = <int>{};
    final normalized = <int>[];
    for (final id in order) {
      if (id < 1) continue;
      if (seen.add(id)) {
        normalized.add(id);
      }
    }
    await setting.put(SettingBoxKey.collectFolderOrder, normalized);
  }

  int getCollectType(BangumiItem bangumiItem) {
    return _collectCrudRepository.getCollectType(bangumiItem.id);
  }

  List<int> getCollectTypes(BangumiItem bangumiItem) {
    return _collectCrudRepository.getCollectTypes(bangumiItem.id);
  }

  Future<void> _recordCollectChange(int bangumiId, int action, int type) async {
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
      collectChangeId,
      bangumiId,
      action,
      type,
      (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    await _collectCrudRepository.addCollectChange(collectChange);
  }

  @action
  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }
    final oldTypes = _collectCrudRepository.getCollectTypes(bangumiItem.id);
    await _collectCrudRepository.addCollectible(bangumiItem, type);
    await _recordCollectChange(bangumiItem.id, oldTypes.isEmpty ? 1 : 2, type);
    loadCollectibles();
  }

  Future<void> toggleCollectType(BangumiItem bangumiItem, int type) async {
    if (type < 1) return;
    final oldTypes = _collectCrudRepository.getCollectTypes(bangumiItem.id);
    final bool hasType = oldTypes.contains(type);
    if (hasType) {
      await _collectCrudRepository.removeCollectType(bangumiItem.id, type);
      final newTypes = _collectCrudRepository.getCollectTypes(bangumiItem.id);
      await _recordCollectChange(
          bangumiItem.id, newTypes.isEmpty ? 3 : 2, type);
    } else {
      await _collectCrudRepository.addCollectType(bangumiItem, type);
      await _recordCollectChange(
          bangumiItem.id, oldTypes.isEmpty ? 1 : 2, type);
    }
    loadCollectibles();
  }

  @action
  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    await _collectCrudRepository.deleteCollectible(bangumiItem.id);
    await _recordCollectChange(bangumiItem.id, 3, 0);
    loadCollectibles();
  }

  Future<void> updateLocalCollect(BangumiItem bangumiItem) async {
    await _collectCrudRepository.updateCollectible(bangumiItem);
    loadCollectibles();
  }

  Future<void> syncCollectibles() async {
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
      return;
    }
    bool flag = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav connection failed', error: e);
      KazumiDialog.showToast(message: 'WebDav连接失败: $e');
      flag = false;
    }
    if (!flag) {
      return;
    }
    try {
      await WebDav().syncCollectibles();
    } catch (e) {
      KazumiDialog.showToast(message: 'WebDav同步失败 $e');
    }
    loadCollectibles();
  }

  // migrate collect from old version (favorites)
  Future<void> migrateCollect() async {
    if (favorites.isNotEmpty) {
      int count = 0;
      for (BangumiItem bangumiItem in favorites) {
        await addCollect(bangumiItem, type: 1);
        count++;
      }
      await _collectCrudRepository.clearFavorites();
      KazumiLogger().d(
          'GStorage: detected $count uncategorized favorites, migrated to collectibles');
    }
  }
}

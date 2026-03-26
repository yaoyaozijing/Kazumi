import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/utils/logger.dart';

/// 收藏CRUD数据访问接口
///
/// 提供收藏数据的增删改查操作
abstract class ICollectCrudRepository {
  /// 获取所有收藏
  List<CollectedBangumi> getAllCollectibles();

  /// 获取单个收藏
  ///
  /// [id] 番剧ID
  /// 返回收藏对象，如果不存在返回null
  CollectedBangumi? getCollectible(int id);

  /// 获取收藏夹类型
  ///
  /// [id] 番剧ID
  /// 返回收藏夹类型值，未收藏返回0
  int getCollectType(int id);

  /// 获取收藏夹列表
  ///
  /// [id] 番剧ID
  /// 返回收藏夹类型列表
  List<int> getCollectTypes(int id);

  /// 添加或更新收藏
  ///
  /// [bangumiItem] 番剧信息
  /// [type] 收藏夹类型
  Future<void> addCollectible(BangumiItem bangumiItem, int type);

  /// 添加到某个收藏夹
  Future<void> addCollectType(BangumiItem bangumiItem, int type);

  /// 从某个收藏夹中移除
  Future<void> removeCollectType(int id, int type);

  /// 从所有番剧中移除某个收藏夹
  Future<void> removeCollectTypeFromAll(int type);

  /// 更新收藏的番剧信息
  ///
  /// [bangumiItem] 更新后的番剧信息
  Future<void> updateCollectible(BangumiItem bangumiItem);

  /// 删除收藏
  ///
  /// [id] 番剧ID
  Future<void> deleteCollectible(int id);

  /// 记录收藏变更（用于WebDAV同步）
  ///
  /// [change] 变更记录
  Future<void> addCollectChange(CollectedBangumiChange change);

  /// 获取旧版收藏列表（用于迁移）
  List<BangumiItem> getFavorites();

  /// 清空旧版收藏（迁移后）
  Future<void> clearFavorites();
}

/// 收藏CRUD数据访问实现类
///
/// 基于Hive实现的收藏CRUD数据访问层
class CollectCrudRepository implements ICollectCrudRepository {
  final _collectiblesBox = GStorage.collectibles;
  final _collectChangesBox = GStorage.collectChanges;
  final _favoritesBox = GStorage.favorites;

  @override
  List<CollectedBangumi> getAllCollectibles() {
    try {
      return _collectiblesBox.values.cast<CollectedBangumi>().toList();
    } catch (e) {
      KazumiLogger().w(
        'GStorage: get all collectibles failed',
        error: e,
      );
      return [];
    }
  }

  @override
  CollectedBangumi? getCollectible(int id) {
    try {
      return _collectiblesBox.get(id);
    } catch (e) {
      KazumiLogger().w(
        'GStorage: get collectible failed. id=$id',
        error: e,
      );
      return null;
    }
  }

  @override
  int getCollectType(int id) {
    try {
      final types = getCollectTypes(id);
      return types.isEmpty ? 0 : types.first;
    } catch (e) {
      KazumiLogger().w(
        'GStorage: get collect type failed. id=$id',
        error: e,
      );
      return 0;
    }
  }

  @override
  List<int> getCollectTypes(int id) {
    try {
      final collectible = _collectiblesBox.get(id);
      return collectible?.effectiveTypes ?? <int>[];
    } catch (e) {
      KazumiLogger().w(
        'GStorage: get collect types failed. id=$id',
        error: e,
      );
      return <int>[];
    }
  }

  @override
  Future<void> addCollectible(BangumiItem bangumiItem, int type) async {
    try {
      final collectedBangumi = _collectiblesBox.get(bangumiItem.id) ??
          CollectedBangumi(
            bangumiItem,
            DateTime.now(),
            type,
          );
      collectedBangumi.bangumiItem = bangumiItem;
      collectedBangumi.time = DateTime.now();
      collectedBangumi.setTypes(<int>[type]);
      await _collectiblesBox.put(bangumiItem.id, collectedBangumi);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: add collectible failed. id=${bangumiItem.id}, type=$type',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> addCollectType(BangumiItem bangumiItem, int type) async {
    if (type < 1) return;
    try {
      final collectedBangumi = _collectiblesBox.get(bangumiItem.id) ??
          CollectedBangumi(
            bangumiItem,
            DateTime.now(),
            type,
          );
      collectedBangumi.bangumiItem = bangumiItem;
      collectedBangumi.time = DateTime.now();
      collectedBangumi.addType(type);
      await _collectiblesBox.put(bangumiItem.id, collectedBangumi);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: add collect type failed. id=${bangumiItem.id}, type=$type',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> removeCollectType(int id, int type) async {
    try {
      final collectible = _collectiblesBox.get(id);
      if (collectible == null) {
        return;
      }
      collectible.removeType(type);
      if (!collectible.isCollected) {
        await _collectiblesBox.delete(id);
      } else {
        collectible.time = DateTime.now();
        await _collectiblesBox.put(id, collectible);
      }
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: remove collect type failed. id=$id, type=$type',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> removeCollectTypeFromAll(int type) async {
    if (type < 1) return;
    try {
      final allItems =
          _collectiblesBox.values.cast<CollectedBangumi>().toList();
      for (final item in allItems) {
        if (!item.containsType(type)) continue;
        item.removeType(type);
        if (!item.isCollected) {
          await _collectiblesBox.delete(item.bangumiItem.id);
        } else {
          item.time = DateTime.now();
          await _collectiblesBox.put(item.bangumiItem.id, item);
        }
      }
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: remove collect type from all failed. type=$type',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateCollectible(BangumiItem bangumiItem) async {
    try {
      final collectible = _collectiblesBox.get(bangumiItem.id);
      if (collectible == null) {
        KazumiLogger().i(
          'GStorage: update collectible failed. collectible not found, id=${bangumiItem.id}',
        );
        return;
      }
      collectible.bangumiItem = bangumiItem;
      await _collectiblesBox.put(bangumiItem.id, collectible);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: update collectible failed. id=${bangumiItem.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteCollectible(int id) async {
    try {
      await _collectiblesBox.delete(id);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: delete collectible failed. id=$id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> addCollectChange(CollectedBangumiChange change) async {
    try {
      await _collectChangesBox.put(change.id, change);
      await _collectChangesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: record collect change failed. changeId=${change.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  List<BangumiItem> getFavorites() {
    try {
      return _favoritesBox.values.cast<BangumiItem>().toList();
    } catch (e) {
      KazumiLogger().i(
        'GStorage: get favorites failed',
        error: e,
      );
      return [];
    }
  }

  @override
  Future<void> clearFavorites() async {
    try {
      await _favoritesBox.clear();
      await _favoritesBox.flush();
    } catch (e) {
      KazumiLogger().i(
        'GStorage: clear favorites failed',
        error: e,
      );
      rethrow;
    }
  }
}

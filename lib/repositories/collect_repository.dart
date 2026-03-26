import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';

/// 收藏数据访问接口
///
/// 提供收藏相关的数据访问抽象，解耦业务逻辑与数据存储
abstract class ICollectRepository {
  /// 获取隐私模式设置
  bool getPrivateMode();
}

/// 收藏数据访问实现类
///
/// 基于Hive实现的收藏数据访问层
class CollectRepository implements ICollectRepository {
  final _settingBox = GStorage.setting;

  @override
  bool getPrivateMode() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.privateMode,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: get private mode setting failed, using default false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

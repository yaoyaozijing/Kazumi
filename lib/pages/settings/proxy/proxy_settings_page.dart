import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_manager.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/request/request.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  Box setting = GStorage.setting;
  late bool proxyEnable;
  late bool enableGitProxy;
  bool proxyConfigExpanded = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController urlController = TextEditingController();
  final TextEditingController testUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    proxyEnable = setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    enableGitProxy =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
    urlController.text = setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    testUrlController.text = setting.get(SettingBoxKey.proxyTestUrl,
        defaultValue: 'https://www.google.com');
  }

  @override
  void dispose() {
    urlController.dispose();
    testUrlController.dispose();
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<void> updateProxyEnable(bool value) async {
    if (value) {
      final proxyConfigured =
          setting.get(SettingBoxKey.proxyConfigured, defaultValue: false);
      if (!proxyConfigured) {
        KazumiDialog.showToast(message: '请先在代理配置中完成测试');
        return;
      }
      await setting.put(SettingBoxKey.proxyEnable, true);
      ProxyManager.applyProxy();
    } else {
      await setting.put(SettingBoxKey.proxyEnable, false);
      ProxyManager.clearProxy();
    }
    setState(() {
      proxyEnable = value;
    });
  }

  Future<void> saveAndTestProxy() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final url = urlController.text.trim();
    if (url.isEmpty) {
      KazumiDialog.showToast(message: '请输入代理地址');
      return;
    }
    final testUrl = testUrlController.text.trim().isEmpty
        ? 'https://www.google.com'
        : testUrlController.text.trim();

    await setting.put(SettingBoxKey.proxyUrl, url);
    await setting.put(SettingBoxKey.proxyTestUrl, testUrl);
    await setting.put(SettingBoxKey.proxyConfigured, false);

    await setting.put(SettingBoxKey.proxyEnable, true);
    ProxyManager.applyProxy();

    try {
      await Request()
          .get(
            testUrl,
            options: Options(
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              validateStatus: (status) => true,
            ),
            shouldRethrow: true,
          )
          .timeout(const Duration(seconds: 15));
      await setting.put(SettingBoxKey.proxyConfigured, true);
      KazumiDialog.showToast(message: '测试成功');
      if (mounted) {
        setState(() {
          proxyEnable = true;
        });
      }
    } catch (e) {
      await setting.put(SettingBoxKey.proxyEnable, false);
      ProxyManager.clearProxy();
      KazumiDialog.showToast(message: '代理连接失败');
      if (mounted) {
        setState(() {
          proxyEnable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('网络设置')),
        body: SettingsList(
          maxWidth: 800,
          sections: [
            SettingsSection(
              title: Text('镜像', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    enableGitProxy = value ?? !enableGitProxy;
                    await setting.put(
                        SettingBoxKey.enableGitProxy, enableGitProxy);
                    setState(() {});
                  },
                  title: Text('GitHub镜像',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('使用镜像访问规则托管仓库',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: enableGitProxy,
                ),
              ],
            ),
            SettingsSection(
              title: Text('代理', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await updateProxyEnable(value ?? !proxyEnable);
                  },
                  title: Text('启用代理', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('启用后网络请求将通过代理服务器',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: proxyEnable,
                ),
                SettingsTile(
                  onPressed: (_) {
                    setState(() {
                      proxyConfigExpanded = !proxyConfigExpanded;
                    });
                  },
                  title: Text('代理配置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                      proxyConfigExpanded ? '点击收起配置区域' : '点击展开配置区域',
                      style: TextStyle(fontFamily: fontFamily)),
                  trailing: Icon(
                    proxyConfigExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                if (proxyConfigExpanded)
                  SettingsTile(
                    title: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: urlController,
                              decoration: const InputDecoration(
                                labelText: '代理地址',
                                hintText: 'http://127.0.0.1:7890',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入代理地址';
                                }
                                if (!ProxyUtils.isValidProxyUrl(value)) {
                                  return '格式错误，请使用 http://host:port 格式';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: testUrlController,
                              decoration: const InputDecoration(
                                labelText: '测试地址',
                                hintText: 'https://www.google.com',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (proxyConfigExpanded)
                  SettingsTile(
                    onPressed: (_) {
                      saveAndTestProxy();
                    },
                    title:
                        Text('保存并测试', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('保存当前代理并执行连接测试',
                        style: TextStyle(fontFamily: fontFamily)),
                    trailing: const Icon(Icons.playlist_add_check_rounded),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

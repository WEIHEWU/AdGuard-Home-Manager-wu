# AdGuard Home Manager

**[📥 点击直接下载安装包 (AdGuardHomeManager.apk)](https://github.com/WEIHEWU/AdGuard-Home-Manager-wu/raw/main/releases/AdGuardHomeManager.apk)** · [Releases 页面](https://github.com/WEIHEWU/AdGuard-Home-Manager-wu/releases) · [配套 Root 模块仓库 (AdGuard-Home-For-Android)](https://github.com/WEIHEWU/AdGuard-Home-For-Android-wu)

基于 Flutter 开发的 **AdGuard Home Manager**，专为 [AdGuard Home For Android](https://github.com/WEIHEWU/AdGuard-Home-For-Android-wu) 本地去广告模块深度定制。

当前版本：`2.24.6`（`versionCode 171`，已同步跟进上游 `JGeek00/adguard-home-manager` `v2.22.2` 最新更新）。

---

## ✨ 定制特性

- **三大模块运维工具（设置 -> 模块设置）**：
  - **模块运行状态与自检**：实时展示 `AdGuardHome` 核心 PID、随机端口、`ADGUARD` (DNS 劫持链) 与 `AGH_SNI` (SNI 嗅探链) 状态，内置 `agh.log` 日志查看器、一键清空日志与一键重载防火墙规则；
  - **清理应用开屏广告缓存**：无需重启手机，随时一键清理知乎、B站、美团、高德、音乐等应用的本地开屏广告缓存；
  - **恢复默认自定义规则**：支持「智能补全（保留自建规则，仅补全缺失的模块默认规则）」与「完全重置为模块出厂默认规则」。
- **同步上游 `v2.22.1` ~ `v2.22.2` 最新核心修复与特性**：
  - 修复新版 AdGuard Home (`v0.108.0-b.84` 及以上)「加密设置」页面因 `allow_unencrypted_doh` 字段移除导致的加载报错；
  - 新增 Android 16/17+ 本地网络权限 (`ACCESS_LOCAL_NETWORK`) 自动检测与请求，解决新版 Android 拦截本地/局域网连接问题；
  - 新增应用内语言切换器（「设置 -> 应用设置 -> 语言」支持切换「跟随系统 / 简体中文 / English」）及 Android 13+ 系统分应用语言同步；
  - 优化加密证书无害提示的 Snackbar 展示体验。
- **模块零配置自动连接**：
  - 启动时通过 Root 权限自动解析 `/data/adb/agh/bin/AdGuardHome.yaml` 中的动态随机管理端口 (`http.address`)，开机或软重启换端口后打开 App 即可无缝重连。
- **`$important` 最高优先级一键放行/拦截**：
  - 在「查询日志」页面点击任意域名执行放行或拦截时，自动生成带 `$important` 修饰符的高优规则（如 `@@||example.com^$important` 或 `||example.com^$important`），确保手动规则 100% 优先于第三方订阅列表，并精确匹配目标域名防止误删子域名规则。
- **双模代理 `PROXY_URL` 订阅管理（即时生效）**：
  - 在「设置 -> 模块设置 -> `PROXY_URL 订阅链接`」中：
    - **留空（默认）**：配合独立 VPN App 使用；
    - **填入订阅链接并保存**：保存瞬间自动触发模块 `ProxyConfig.sh --once` 将订阅地址与最新本地 DNS 端口同步至 Box / Clash / Mihomo 并温和重启代理服务。
- **Miuix 界面细节修复**：
  - 修复原版在部分深色/动态取色主题下 `CustomRadioListTile` 单选按钮边框透明不可见的显示 Bug。
- **通知栏快捷磁贴 (Quick Settings Tile)**：
  - 支持在系统下拉通知栏添加「AdGuard Home」快捷开关磁贴，一键暂停或恢复过滤。

---

## 🛠️ 构建方法

需要 Flutter `3.22+` 与 Android SDK：

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 致谢与开源许可

- 上游原版项目：[JGeek00/adguard-home-manager](https://github.com/JGeek00/adguard-home-manager)
- 模块适配分支参考：[liuzq2002/adguard-home-manager-mod](https://github.com/liuzq2002/adguard-home-manager-mod)
- 修改与维护：春梦无痕
- 开源协议：GNU General Public License v3.0 (GPL-3.0)，详见 [LICENSE.md](LICENSE.md)。

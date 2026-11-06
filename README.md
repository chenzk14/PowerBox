# PowerBox

<p align="center">
  <a href="https://github.com/chenzk14/PowerBox/tags"><img alt="Latest tag" src="https://img.shields.io/github/v/tag/chenzk14/PowerBox?sort=semver&color=333333"></a>
  <a href="https://github.com/chenzk14/PowerBox/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/chenzk14/PowerBox?style=flat&logo=github&color=F59E0B"></a>
  <a href="https://github.com/chenzk14/PowerBox/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/chenzk14/PowerBox?style=flat&logo=github"></a>
  <a href="https://pubspec.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44.5-02569B?logo=flutter&logoColor=white"></a>
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart&logoColor=white">
  <img alt="Kotlin" src="https://img.shields.io/badge/Kotlin-2.2.20-7F52FF?logo=kotlin&logoColor=white">
  <img alt="No ads" src="https://img.shields.io/badge/ads-none-16A34A">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-333333">
</p>

PowerBox 是一款本地优先的 Android 效率工具，基于 Flutter：打卡、密码与快递管理，附带电池和时钟桌面小组件。黑白简约界面。

**软件预览**：[查看设计稿](https://www.kdocs.cn/l/crDSV8PhJBoh)

所有敏感数据都使用 AES-256-CBC 加密后保存在本地，不上传服务器。除检查更新外，应用不需要联网。

## 为什么做它

很多手机效率应用要么收费，要么满是广告，要么要求你把数据放到云端。PowerBox 想做的是：

- **本地优先**：密码、快递等敏感数据全部 AES-256-CBC 加密后存本地，不收集、不上传
- **无广告**：不加广告，没有会员/订阅/解锁
- **工具型**：功能少而明确，不做复杂配置
- **黑白简约**：黑白为主，不喧宾夺主

## 功能一览

| 功能 | 说明 |
| --- | --- |
| 一键打卡 | 首页一个按钮完成打卡，支持日历查看、事件管理与月度/年度统计 |
| 密码管理 | AES-256-CBC 加密存储，支持生物识别解锁、搜索、卡片查看与复制、数据导入导出、自定义图标 |
| 快递管理 | AES-256-CBC 加密存储；取件码、驿站、地址、尾号、备注；复制短信后一键识别；待取/已取切换 |
| 常用工具 | 快递管理入口、电池信息（校准容量并添加桌面电池小组件） |
| 电池桌面小组件 | 桌面显示实时容量/最大容量、温度电压、充电功率；支持手动校准，自动刷新 |
| 时钟桌面小组件 | 2x2 黑底白字，显示时间、日期、星期与电量，自动刷新 |

## 技术架构

- **UI**：Flutter（页面、统计、图表）
- **桌面小组件**：原生 Android（Kotlin），AppWidget + RemoteViews
- **Flutter ↔ 原生通信**：MethodChannel（电池信息、小组件刷新、桌面快捷方式跳转）
- **本地存储**：SharedPreferences（敏感数据加密后存储，其余存本地）

## 运行

```bash
git clone https://github.com/chenzk14/PowerBox.git
cd PowerBox
flutter pub get
flutter run
```

## 打包

```bash
flutter build apk --release

# 按 ABI 拆分，进一步压缩体积
flutter build apk --release --split-per-abi
```

## 许可证

MIT License

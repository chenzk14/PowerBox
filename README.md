# PowerBox

本地优先的打卡与密码管理工具，基于 Flutter，黑白简约界面。

**软件预览**：[查看设计稿](https://www.kdocs.cn/l/crDSV8PhJBoh)

## 功能

- **一键打卡**：点击即完成打卡，支持日历查看、事件管理与月度/年度统计。
- **密码管理**：AES-256-CBC 本地加密存储，支持生物识别解锁、搜索、卡片式查看与复制。
- **本地优先**：数据保存在设备本地，不上传服务器，除版本检查外无网络请求。

## 设计原则

- **极简**：首页一个按钮完成打卡；密码卡片展开才显示敏感信息，收起即保护。
- **隐私**：数据仅存本地，不收集、不跟踪，完全离线可用。
- **安全**：AES-256-CBC 加密，密钥由系统安全随机生成；支持指纹、面容、PIN 等认证方式。
- **纯粹**：MIT 开源，无广告，不申请无关权限。

## 项目结构

```
lib/
├── main.dart          # 应用入口与底部导航
├── models/            # 事件、密码数据模型
├── services/          # 本地存储、导入导出、密码加密、更新检查
├── pages/             # 打卡、统计、设置、密码管理
├── widgets/           # 顶部栏、圆形操作按钮
└── utils/             # Toast 提示
```

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

## 版本号

格式 `x.y.z+n`：`x.y.z` 为显示给用户的版本号，`n` 为内部构建号。

## 许可

MIT License

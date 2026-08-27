# 一键打卡 App

Flutter 打卡应用，支持日历视图、数据统计、数据管理和密码本地管理。

**软件预览**：[查看设计稿](https://www.kdocs.cn/l/crDSV8PhJBoh)

## 功能特性

### 首页
- **一键打卡** - 点击按钮快速记录打卡事件，支持同一日期多次打卡
- **日历视图** - 中文星期显示，点击时间区域可快速切换年月
- **事件统计** - 显示当月打卡次数及与上月对比
- **实时时间** - 显示当前日期和时间

### 统计页面
- **年度统计** - 平滑折线图展示每月打卡趋势
- **月度详情** - 显示各日期打卡次数（如"5（4次）"）
- **年份切换** - 水平滑动选择不同年份

### 数据管理
- **数据备份** - 将数据备份到本地文件
- **数据导出** - 导出 JSON 格式文件用于分享
- **数据导入** - 从 JSON 文件导入数据
- **权限管理** - 管理存储权限
- **密码管理** - 安全存储账号密码，支持生物识别/设备解锁认证
  - 卡片式列表，点击展开查看账号/密码详情
  - 顶部搜索栏，支持按名称搜索
  - 右滑快捷复制，左滑删除记录
  - 账号密码 AES-256 加密本地存储

### 密码管理
- **安全认证** - 支持指纹、面容 ID、PIN 码、图案解锁（未设置锁屏时自动跳过）
- **加密存储** - 使用 AES-CBC 模式加密，密钥安全生成并持久化
- **交互优化** - 卡片展开动画、左滑删除确认、右滑快速复制、实时搜索过滤

## 技术栈

- Flutter 3.0+
- Dart 3.0+
- Syncfusion Flutter Charts - 折线图展示
- Table Calendar - 日历组件
- Shared Preferences - 本地数据存储
- Path Provider - 文件路径管理
- File Picker - 文件选择器
- Permission Handler - 权限管理
- **encrypt** - AES 加密存储
- **local_auth** - 生物识别/设备凭据认证

## 项目结构

```
lib/
├── main.dart                 # 应用入口与底部导航
├── models/                   # 数据模型
│   ├── event_model.dart      # 事件数据模型
│   └── password_model.dart   # 密码条目数据模型
├── services/                 # 业务服务层
│   ├── local_storage.dart    # 本地存储管理
│   ├── file_storage.dart     # 文件存储管理
│   ├── password_storage.dart # 密码加密存储
│   └── update_service.dart   # 版本更新检查
├── pages/                    # 页面组件
│   ├── home_page.dart            # 首页（打卡页面）
│   ├── statistics_page.dart      # 统计页面
│   ├── data_management_page.dart # 数据管理页面
│   ├── password_manager_page.dart # 密码管理页面
│   └── add_password_page.dart    # 添加/编辑密码页面
└── utils/                    # 工具类
    └── toast_util.dart       # Toast 提示工具
```

## 安装运行

1. 确保已安装 Flutter SDK
2. 克隆项目：
```bash
git clone <your-repo-url>
cd todo_list_app
```

3. 安装依赖：
```bash
flutter pub get
```

4. 运行应用：
```bash
flutter run
```

## 打包发布

```bash
flutter build apk --release
```
#### 打包时可以进一步压缩 APK 文件大小
```bash
flutter build apk --release --split-per-abi
```

## 版本说明

版本号格式：`x.y.z+n`
- `x.y.z` - 版本号（显示给用户）
- `n` - 构建号（内部版本）

每次发布新版需手动修改 `pubspec.yaml` 中的 `version` 字段。

## 许可证

MIT License

# Quick Box

Quick Box 是一个 Flutter 实现的 Android 快速启动器。

## 功能

- 搜索应用
- 点击启动应用
- 获取设备上全部可启动应用
- 应用图标按需加载（降低启动崩溃风险）

## 平台说明

- 仅支持 Android
- 不支持 Windows / iOS / macOS / Linux

## 运行

```bash
flutter pub get
flutter run
```

## Android 权限与可见性

`android/app/src/main/AndroidManifest.xml` 已包含:

- `android.permission.QUERY_ALL_PACKAGES`
- launcher intent 的 `<queries>` 配置

如果后续上架应用商店，需要按商店政策提供使用说明。
# Feiniu Player

飞牛影视第三方 Flutter 客户端（Android / iOS 规划中）。

## 功能

- 登录 / 记住密码 / 多账号
- 媒体库浏览、继续观看
- 详情页、剧集选集
- STRM 直链播放（MPV 内核）
- 续播、倍速、字幕 / 音轨切换、进度上报

## 手机测试：两种方式

### 方式 A：GitHub 自动打包（推荐）

适合「电脑不方便连手机调试」的情况。

1. 在 GitHub 新建仓库，把本项目 push 上去
2. **手动触发**：Actions → `Build Android APK` → Run workflow
3. 或 **打 tag 自动发 Release**：
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
4. 到 **Releases** 或 **Actions Artifacts** 下载 `FeiniuPlayer_*.apk`
5. 传到手机安装（需允许「未知来源」）

> 手机需与 NAS **同一局域网**，或 NAS 有外网地址；登录填 `http://192.168.x.x:8005`

### 方式 B：本机打包 APK

```powershell
cd f:\otherCode\cursor\player
flutter pub get
flutter build apk --release
```

APK 路径：

```
build\app\outputs\flutter-apk\app-release.apk
```

用微信 / 网盘 / USB 发到手机安装即可。

## 本地开发

```powershell
flutter pub get
flutter run
```

## API 探测（可选）

```powershell
$env:FNOS_HOST="http://192.168.100.10:8005"
$env:FNOS_USER="home"
$env:FNOS_PASS="你的密码"
python tools/verify_login.py
python tools/verify_stream.py
```

## 技术栈

- Flutter + Riverpod
- Dio + Authx（fntv_danmu_all 同款鉴权）
- media_kit (libmpv)

## 声明

第三方客户端，与飞牛影视官方无关。

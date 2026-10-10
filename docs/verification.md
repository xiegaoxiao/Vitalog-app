# 首版验证记录

日期：2026-10-10。版本：0.1.0+1。

## 已验证

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：16 项全部通过，覆盖业务事务、导入、备份和 360px 手机界面。
- 公共输入框修复：填充布局让浮动标签留在圆角背景内；几何回归检查覆盖已填/空值、聚焦、数字、多行、下拉框、浅深色及 1.5 倍字体。浏览器在 755×688 和 412×915 检查餐食表单，截图 `output/screenshots/input-fields-fixed.jpg` 与 `input-fields-fixed-mobile.jpg`。
- `flutter build web --no-web-resources-cdn --no-pub`：成功。
- `scripts/build-android.ps1`：release APK 构建成功，约 35.7 MB。
- 官方 `apksigner verify --verbose`：APK v2 签名验证通过，使用开发签名供个人试用。
- 官方 `aapt2 dump badging`：包名 `com.vitalog.vitalog`，版本 `0.1.0`，应用名「元气簿」，最低 API 24，target/compile API 36。
- 最终 APK 无 INTERNET 权限；AI 生成由用户在外部完成。
- 浏览器手动验证：午餐实际摄入记录、库存扣减、JSON 粘贴导入、逐项修改预览、确认保存、训练实际重量和次数、自动休息倒计时。
- 手机 412×915 与桌面 1280×720 视觉检查，截图位于 `output/screenshots/`。

APK：`output/Vitalog-0.1.0-arm64.apk`。

SHA256：`BB00A369E68585992524E4E98C6A339C6D1AC981D393C95648E41ABBFAEE21ED`。

## 卡通风格更新

粉色背景、奶白卡片、黑色轮廓与偏移阴影，食谱/训练/日历/习惯保留各自的糖果色。首页、身体档案和空状态使用离线小伙伴插画，饮食卡片显示完整卡通小碗；图标与原生启动图标同步更新。输入框使用填充布局的自定义圆角描边，继续通过标签位置回归检查。

最终静态检查无问题，16 项测试通过，网页与 APK 均构建成功，APK 签名验证通过。浏览器检查了首页、饮食、日历、训练、档案与表单的手机布局，以及 1280px 宽屏。卡通版截图位于 `output/screenshots/cartoon-*.jpg`，素材与最终提示词见 `docs/assets.md`。

## 真机待验证

当前没有连接安卓设备，因此没有声称完成 realme Android 16 真机测试。浏览器预览与安卓数据库独立，浏览器预览不发送安卓通知。

安装后在「我的 → 提醒与权限」授予通知和精确提醒权限，执行提醒测试。再分别检查：应用退出到后台、锁屏、重启、修改计划、关闭权限、可选闹钟关闭按钮。realme 如限制后台运行，可在系统应用设置中允许后台活动。备份文件选择与恢复也需在手机上检查。

首版适合个人试用；商店发布需要独立的正式签名与真机验收。

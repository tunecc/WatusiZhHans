# WatusiZhHans-roothide

给 `com.fouadraheb.watusi3_1.3.9_iphoneos-arm64.deb` 做的 roothide / rootless 中文包工程。

## 设计

- 工程类型：Theos `iphone/tweak`
- 打包方案：`THEOS_PACKAGE_SCHEME=roothide`
- 路径策略：roothide 模块不会像 rootless 模块那样自动补 `/var/jb` 前缀；本工程是纯资源包，所以直接按原始 deb 的实际落点保留 `layout/var/jb/...`
- 覆盖方式：资源覆盖 + 极小运行时 Hook，不改动 Watusi 原二进制
- 自动语言兼容：除 `zh-Hans.lproj` 外，同时生成 `zh.lproj`、`zh_CN.lproj`、`zh-CN.lproj`、`zh_Hans.lproj`、`zh-Hans-CN.lproj`、`zh_Hans_CN.lproj`
- 覆盖路径：
  - `var/jb/Library/Application Support/Watusi/Resources.bundle/zh-Hans.lproj/Localizable.strings`
  - `var/jb/Library/ControlCenter/Bundles/WatusiToggle.bundle/zh-Hans.lproj/Localizable.strings`
- 运行时行为：
  - 注入 `WhatsApp`
  - hook `FRSListCell` 的 `setListItems:` / `setListValues:`
  - 只在识别到 Watusi 语言菜单时追加 `简体中文` / `zh-Hans`

## 源数据

- 英文基准 strings 来自已解包的原始 deb：
  - `../extracted/watusi/var/jb/Library/Application Support/Watusi/Resources.bundle/en.lproj/Localizable.strings`
  - `../extracted/watusi/var/jb/Library/ControlCenter/Bundles/WatusiToggle.bundle/en.lproj/Localizable.strings`
- `sources/translations/common_value_overrides.json`：常见短文本的全局翻译
- `sources/translations/resources_key_overrides.json`：主资源包重点条目的键级翻译
- `sources/translations/toggle_key_overrides.json`：Control Center toggle 全量翻译

## 生成与打包

```sh
cd WatusiZhHans-roothide
make package FINALPACKAGE=1
```

生成脚本会：

1. 用英文 strings 作为完整兜底
2. 叠加中文精确翻译
3. 输出到 `layout/.../zh-Hans.lproj/Localizable.strings`
4. 导出 CSV 清单到 `output/spreadsheet/watusi_zh_hans_inventory.csv`
5. 额外导出未翻译条目到 `output/spreadsheet/watusi_zh_hans_missing.csv`

## 当前状态

- 已完整覆盖 Control Center Toggle 文案
- 已覆盖主资源包中最常见的入口、分区、按钮和核心功能说明
- 未单独翻译的条目会保留英文值，不会掉成原始 key
- 可以直接用 `output/spreadsheet/watusi_zh_hans_missing.csv` 继续人工补翻
- 由于 Watusi 1.3.9 的语言菜单选项是代码侧枚举，本工程现在通过运行时 hook 补出 `简体中文` 选项；同时仍保留 `Language = Auto` + 中文 locale 别名的自动命中路径

## 安装后验证

- 重新打开 WhatsApp
- 打开 `Other Settings -> Language`，确认出现 `简体中文`
- 如需立即看到 Control Center 文案变化，重开控制中心或执行一次 respring

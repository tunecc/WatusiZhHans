基于 **Watusi 1.3.9** 开发的的简体中文语言包工程。

作用：

1. 添加中文翻译
2. 用最小运行时 hook 把 `Other Settings -> Language -> 简体中文` 补进菜单

---

## 安装与使用

1. 安装本 deb
2. 彻底杀掉 `WhatsApp`
3. 重新打开 `WhatsApp`
4. 进入 `Watusi -> Other Settings -> Language`
5. 选择 `简体中文`

如果不手动切换，也可以尝试：

- `Language = Auto`
- WhatsApp / 系统语言为简体中文

---

## 后续维护建议

如果后面继续迭代，建议按这个顺序推进：

1. 调整 `sources/translations/*.json` 中的翻译覆写
2. 重新打包并检查 `summary.json` / `inventory.csv`
3. 实机核对重点页面的文案语气和长度
4. 如果 Watusi 升级，再重新确认：
   - `wTweakLanguage`
   - 语言列表构造方法
   - `FRSListCell` 相关构造签名是否变化

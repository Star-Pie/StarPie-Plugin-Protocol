# 插件提交

此目录保存插件收录规则和提交信息模板。实际插件包应上传到本仓库的 GitHub Releases，不提交到 Git 文件树。

提交一个新插件或新版本时，需要：

1. 按 SPP 规范构建 `.sppkg`。
2. 创建固定版本的 GitHub Release 并上传插件包。
3. 计算插件包 SHA-256。
4. 新建或更新 `registry/plugins/<pluginId>.json`。
5. 更新 `registry/index.json`；已有插件发布新版本时不重复添加索引项。
6. 按 `plugin-submission-template.md` 准备提交信息。
7. 发起 Pull Request。

提交前请确认插件没有携带 `StarPie.dll` 或私有的 `StarPie.Plugin.Abstractions.dll`。

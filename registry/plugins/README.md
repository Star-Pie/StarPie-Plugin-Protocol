# 插件登记目录

每个插件使用独立目录：

```text
<pluginId>/
├─ plugin.json
└─ versions/
   └─ <version>.json
```

- 第一次提交：[提交第一个社区插件](../../docs/getting-started/first-plugin-submission.md)
- 发布新版本：[发布插件新版本](../../docs/getting-started/release-new-version.md)
- 完整注册表规则：[registry/README.md](../README.md)

插件包托管在发布者自己的固定 GitHub Release，不提交到本目录。修改登记信息后运行：

```powershell
pwsh ./tools/Test-CommunityRegistry.ps1 -VerifyPackages
pwsh ./tools/Update-CommunityCatalog.ps1
```

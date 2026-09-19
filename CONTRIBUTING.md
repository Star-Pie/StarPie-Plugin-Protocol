# 参与 StarPie Plugin Protocol

## 先选择贡献类型

- 修改 SPP 公共规则：阅读 [SPP 1.0](docs/protocol/SPP-1.0.md) 和目标能力路径。
- 开发第三方插件：从 [发布者注册](docs/getting-started/publisher-registration.md) 开始。
- 提交第一个插件：阅读 [第一个插件提交教程](docs/getting-started/first-plugin-submission.md)。
- 发布已有插件的新版本：阅读 [新版本发布教程](docs/getting-started/release-new-version.md)。
- 维护社区注册表：阅读 [registry/README.md](registry/README.md)。

完整入口见 [文档导航](docs/README.md)。

## 修改协议

修改协议前必须阅读根目录 `AGENTS.md`。SPP 1.x 已公开的稳定规则只增不改，不兼容变化留给新的主版本。

协议文档描述插件与宿主必须遵守的行为，不复制 StarPie 主仓库的完整内部架构。当前官方实现进度和源码映射写入 `docs/implementation/`。

## 提交社区插件

1. 完成发布者注册。
2. 将 `.spkg` 托管在发布者自己的固定版本 GitHub Release。
3. 复制 `templates/community-plugin.example.json` 和 `templates/community-plugin-version.example.json`。
4. 将文件放入 `registry/plugins/<pluginId>/`。
5. 运行：

```powershell
pwsh ./tools/Test-CommunityRegistry.ps1 -VerifyPackages
pwsh ./tools/Update-CommunityCatalog.ps1
pwsh ./tools/Update-CommunityCatalog.ps1 -Check
```

6. 提交源文件和生成的 `registry/index.json`、`registry/generated/community-catalog.json`。
7. 使用对应 PR 模板说明能力、兼容性和风险变化。

不要提交插件二进制、私有凭据、个人邮箱或 StarPie 主程序程序集。

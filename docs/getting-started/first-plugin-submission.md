# 提交第一个社区插件

本文面向已经完成[发布者注册](publisher-registration.md)的第三方开发者。

## 1. 准备插件

插件必须遵守 [插件包与配置](../development/plugin-package-and-configuration.md)：

- 只引用 `StarPie.Plugin.Abstractions` 和宿主允许的框架程序集；
- 不引用 `StarPie.dll`；
- 发布包不携带私有 `StarPie.Plugin.Abstractions.dll`；
- 插件 ID 位于自己的 `io.github.<login>` 命名空间；
- 包内根目录包含 `plugin.json` 和入口 DLL。

## 2. 创建固定版本 Release

在自己的公开 GitHub 插件仓库中：

1. 创建固定版本 Tag，例如 `v1.0.0`；
2. 构建 `.spkg`；
3. 创建对应 GitHub Release；
4. 上传：

```text
<pluginId>-<version>.spkg
```

例如：

```text
io.github.example-dev.hello-1.0.0.spkg
```

不要使用 `latest` 下载地址，也不要在发布后替换同版本 Asset。

## 3. 创建插件登记文件

复制：

```text
templates/community-plugin.example.json
```

保存到：

```text
registry/plugins/<pluginId>/plugin.json
```

填写插件名称、发布者、源码仓库、许可证、能力和发布通道。

## 4. 创建版本登记文件

复制：

```text
templates/community-plugin-version.example.json
```

保存到：

```text
registry/plugins/<pluginId>/versions/<version>.json
```

填写：

- Source Tag 和完整 Commit SHA；
- SDK 与 StarPie 兼容范围；
- 固定 Release Asset 地址；
- SHA-256；
- 文件大小；
- 本版本能力声明。

## 5. 本地检查

在仓库根目录运行：

```powershell
pwsh ./tools/Test-CommunityRegistry.ps1 -VerifyPackages
pwsh ./tools/Update-CommunityCatalog.ps1
pwsh ./tools/Update-CommunityCatalog.ps1 -Check
```

第一个命令会下载插件包并做静态检查，但不会加载或执行插件 DLL。

## 6. 发起 Pull Request

提交：

- 插件级 `plugin.json`；
- 版本级 `versions/<version>.json`；
- 重新生成的 `registry/index.json`；
- 重新生成的 `registry/generated/community-catalog.json`。

GitHub 会自动校验提交者所有权、包哈希、清单内容和生成文件。首次插件仍需 StarPie 社区维护者人工审核。

完整的数据结构、状态和撤回规则见 [注册表结构与分发规则](../../registry/README.md)。

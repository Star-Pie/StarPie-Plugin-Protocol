# 发布插件新版本

本文适用于已经登记在社区注册表中的插件。

## 1. 不要修改旧版本

已发布版本的以下内容不可修改：

- 版本号；
- 下载地址；
- SHA-256 和文件大小；
- Source Tag 与 Commit；
- SDK 和宿主兼容范围；
- 能力声明。

内容有变化时必须发布新的语义化版本，例如从 `1.0.0` 升级到 `1.0.1`。

## 2. 发布新的 GitHub Release

在插件自己的仓库中：

1. 创建新 Tag；
2. 构建新的 `.spkg`；
3. 创建固定版本 Release；
4. 上传名称匹配的新 Asset。

## 3. 新增版本文件

在下面目录新增文件：

```text
registry/plugins/<pluginId>/versions/<newVersion>.json
```

不要覆盖旧版本文件。

## 4. 更新发布通道

在插件的 `plugin.json` 中更新：

- 正式版本使用 `channels.stable`；
- 测试版本使用 `channels.beta`。

通道只能指向同一通道中状态为 `active` 的版本。

## 5. 检查并提交

运行：

```powershell
pwsh ./tools/Test-CommunityRegistry.ps1 -VerifyPackages
pwsh ./tools/Update-CommunityCatalog.ps1
pwsh ./tools/Update-CommunityCatalog.ps1 -Check
```

然后发起版本更新 PR，明确说明：

- 用户可见变化；
- 兼容性变化；
- 是否新增或扩大能力；
- 是否增加原生 DLL、网络、进程启动、屏幕捕获或输入模拟。

## 6. 撤回问题版本

不要删除版本文件。根据严重程度修改版本状态：

- `yanked`：不再推荐新安装；
- `revoked`：存在严重安全或稳定性问题。

同时填写 `reason`，必要时填写 `replacedBy` 或 `advisory`。详细规则见 [注册表结构与分发规则](../../registry/README.md)。

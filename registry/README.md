# 插件注册表与分发

## 1. 分工

本仓库同时保存 SPP 协议和社区注册表，但两者使用不同的维护路径：

- `docs/` 保存稳定协议和开发规则；
- `registry/publishers/` 保存第三方发布者身份；
- `registry/plugins/` 保存插件元信息和不可变版本记录；
- `registry/generated/` 保存由工具生成的社区 catalog；
- 第三方开发者自己的 GitHub Releases 保存实际 `.spkg` 包。

第三方插件包不得上传到本仓库的 Git 文件树，也不要求上传到本仓库 Releases。社区仓库只索引固定版本下载地址和 SHA-256。

## 2. 注册表结构

```text
registry/
├─ index.json
├─ generated/
│  └─ community-catalog.json
├─ publishers/
│  ├─ README.md
│  └─ github-<userId>.json
└─ plugins/
   ├─ README.md
   └─ <pluginId>/
      ├─ plugin.json
      └─ versions/
         └─ <version>.json
```

发布者、插件和版本文件是事实来源。`index.json` 与 `community-catalog.json` 必须通过以下命令生成，不得手工拼接：

```powershell
pwsh ./tools/Update-CommunityCatalog.ps1
```

## 3. 发布者注册

发布者注册规则见 [第三方发布者注册](../docs/getting-started/publisher-registration.md)。MVP 使用 GitHub 数字用户 ID 作为稳定身份，并自动验证 `io.github.<login>` 命名空间。

## 4. 插件元信息

每个插件目录包含一个 `plugin.json` 注册文件。它描述所有权、名称、仓库、许可证、路径分类、能力上限、发布通道和插件状态。

模板和 Schema：

- [community-plugin.example.json](../templates/community-plugin.example.json)
- [plugin.schema.json](../schemas/plugin.schema.json)

插件 ID 一旦发布不得修改。需要更名时应注册新插件，并将旧插件标记为 `deprecated`，通过 `replacedBy` 指向新 ID。

## 5. 版本记录

每个版本单独保存，不把全部历史塞入一个持续膨胀的插件文件：

```text
registry/plugins/io.github.example-dev.hello/versions/1.0.0.json
```

模板和 Schema：

- [community-plugin-version.example.json](../templates/community-plugin-version.example.json)
- [plugin-version.schema.json](../schemas/plugin-version.schema.json)

已发布版本的包地址、哈希、源码 Commit、兼容范围和能力声明不可修改。允许修改的只有撤回相关字段：`status`、`reason`、`replacedBy` 和 `advisory`。

## 6. 包格式与托管

社区与官方插件统一使用 `.spkg`。它是 ZIP 分发容器，运行时仍然加载解压后的 DLL。

文件名固定为：

```text
<pluginId>-<version>.spkg
```

下载地址必须是发布者仓库中的固定 GitHub Release Asset：

```text
https://github.com/<owner>/<repo>/releases/download/<tag>/<pluginId>-<version>.spkg
```

禁止使用 `latest` 地址。发布后不得替换同版本 Asset；内容变化必须发布新版本。

## 7. 收录流程

```text
注册 GitHub 发布者
→ 在自己的公开仓库开发插件
→ 创建固定 Tag 与 GitHub Release
→ 上传 .spkg
→ 计算 SHA-256 与文件大小
→ 新建插件和版本注册文件
→ 运行 catalog 生成工具
→ 发起 PR
→ CI 校验身份、结构、所有权、不可变字段和插件包
→ 人工审核首次插件或能力扩大
→ 合并后发布社区 catalog 构建产物
```

## 8. 自动校验

`tools/Test-CommunityRegistry.ps1` 检查：

- 发布者、命名空间和维护者关系；
- 插件 ID、目录名、仓库所有者和发布者关系；
- SemVer、通道引用和兼容范围；
- 固定 Release URL、SHA-256 和文件大小；
- 已发布版本不可变字段；
- PR 作者是否是目标发布者维护者；
- ZIP 路径穿越、重复条目、数量和解压大小；
- 包内 `plugin.json` 与注册记录是否一致；
- 禁止携带 `StarPie.dll` 和 `StarPie.Plugin.Abstractions.dll`。

校验器不会加载或执行插件 DLL。自动检查只能证明身份、结构和完整性，不能证明第三方代码安全。

## 9. 状态与撤回

插件状态：`active`、`deprecated`、`blocked`。

版本状态：`active`、`yanked`、`revoked`。

撤回和封禁必须保留历史记录，不通过删除文件实现。`stable` 和 `beta` 通道只能指向对应通道中的 active 版本。

## 10. Catalog 与客户端

`community-catalog.json` 是客户端消费接口，Git 文件树布局是注册表实现细节。当前 MVP 工作流会验证并上传 catalog 构建产物；正式默认启用社区在线安装前，还应增加独立签名与客户端签名验证。

StarPie 客户端必须把社区插件标记为第三方进程内代码，展示发布者、源码仓库、许可证、能力和风险提示，并在安装前验证 catalog、包 SHA-256 与包内清单。

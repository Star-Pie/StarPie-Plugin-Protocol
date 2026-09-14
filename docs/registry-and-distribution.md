# 插件注册表与分发

## 1. 分工

本仓库同时保存 SPP 协议和官方插件注册表：

- Git 文件树保存协议、插件索引和插件注册信息；
- GitHub Releases 保存实际 `.sppkg` 插件包；
- StarPie 先读取注册表，再下载指定版本的 Release Asset。

插件二进制不直接提交到 `registry/` 或其他 Git 目录。

## 2. 注册表结构

```text
registry/
├─ index.json
└─ plugins/
   ├─ README.md
   └─ <pluginId>.json
```

`index.json` 是轻量入口，只列出已经收录的插件：

```json
{
  "schemaVersion": "1.0",
  "updatedAt": "2026-09-16",
  "plugins": [
    {
      "id": "com.example.hello",
      "manifest": "plugins/com.example.hello.json"
    }
  ]
}
```

每个插件注册文件保存详细版本信息：

```json
{
  "schemaVersion": "1.0",
  "id": "com.example.hello",
  "name": "Hello Plugin",
  "description": "提供示例问候动作。",
  "publisher": "Example",
  "latestVersion": "1.0.0",
  "paths": [
    "action-execution"
  ],
  "versions": {
    "1.0.0": {
      "sppVersion": "1.0",
      "minimumStarPieVersion": "1.8.0",
      "asset": {
        "fileName": "com.example.hello-1.0.0.sppkg",
        "downloadUrl": "固定版本的 GitHub Release Asset 地址",
        "sha256": "插件包 SHA-256"
      }
    }
  }
}
```

下载地址必须指向固定版本的 Release Asset，不能使用仓库级的 `latest` 地址。

## 3. 插件包

`.sppkg` 是 ZIP 格式的插件包，文件名建议为：

```text
<pluginId>-<version>.sppkg
```

包内至少包含：

```text
plugin-package/
├─ plugin.json
├─ Plugin.dll
└─ assets/          # 可选
```

包内规则见 [插件包与配置](plugin-package-and-configuration.md)。

## 4. Release 命名

建议一个插件版本对应一个 GitHub Release：

```text
Tag:   plugin-<pluginId>-v<version>
Asset: <pluginId>-<version>.sppkg
```

例如：

```text
Tag:   plugin-com.example.hello-v1.0.0
Asset: com.example.hello-1.0.0.sppkg
```

发布后不应替换同版本 Asset。内容变化必须发布新的插件版本并更新注册表。

## 5. 收录流程

```text
开发者构建插件
→ 生成 .sppkg
→ 计算 SHA-256
→ 创建固定版本 Release
→ 提交插件注册文件
→ 更新 registry/index.json
→ 发起 PR
→ 检查清单、兼容性、下载地址和哈希
→ 合并后 StarPie 可以发现新版本
```

初期可以人工检查。后续 Action 应校验 JSON 格式、ID 唯一性、版本递增、下载可用性、SHA-256 和包内 `plugin.json` 一致性。

## 6. StarPie 下载流程

```text
读取 registry/index.json
→ 读取目标插件注册文件
→ 选择与当前宿主兼容的版本
→ 下载固定 Release Asset
→ 校验 SHA-256
→ 解压到临时目录
→ 校验 plugin.json 和 DLL
→ 展示能力与调用路径
→ 用户确认安装
```

校验失败时不得安装，也不得覆盖已安装的可用版本。

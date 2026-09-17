# 插件包与配置

## 1. 插件包

正式插件包至少包含：

```text
plugin-package/
├─ plugin.json
├─ Plugin.dll
└─ assets/          # 可选
```

插件包不得携带：

- `StarPie.dll`；
- 私有副本 `StarPie.Plugin.Abstractions.dll`；
- 未在清单中说明的可执行载荷。

入口程序集的目标框架不得高于宿主支持的目标框架。插件项目引用 SDK 时必须设置为不复制到输出目录。

## 2. 当前官方宿主支持的 `plugin.json`

当前可运行的最小示例应以 `StarPie.Plugin.Abstractions/PluginManifest.cs` 和主仓库 `samples/HelloAction/plugin.json` 为准：

```json
{
  "schemaVersion": 1,
  "id": "com.example.hello",
  "name": "Hello Plugin",
  "description": "示例插件",
  "author": "Example",
  "license": "MIT",
  "version": "1.0.0",

  "apiVersion": "1.0",
  "minHostVersion": "1.7.4",

  "targetFramework": "net8.0-windows",
  "platform": "win-x64",

  "assembly": "StarPie.Plugin.HelloAction.dll",
  "entryType": "StarPie.Plugin.HelloAction.HelloActionPlugin",

  "capabilities": [],

  "contributions": {
    "actions": true,
    "icons": true,
    "i18n": true
  },

  "tags": ["示例"]
}
```

### 主要字段

| 字段 | 当前规则 |
|---|---|
| `schemaVersion` | 整数，当前为 `1` |
| `id` | 全局稳定的反向域名 ID，建议全小写 |
| `name` | 默认显示名称 |
| `description` | 简短说明 |
| `author` | 作者或组织 |
| `license` | SPDX 许可证标识 |
| `version` | 插件语义化版本 |
| `apiVersion` | 插件编译依赖的 SDK 契约版本，主版本必须兼容 |
| `minHostVersion` | 最低可运行宿主版本 |
| `maxHostVersion` | 可选，最高可运行宿主版本 |
| `targetFramework` | `net8.0-windows` 或宿主支持的兼容 TFM |
| `platform` | 当前官方宿主为 `win-x64` |
| `assembly` | 入口程序集相对路径；留空时宿主可按约定推断 |
| `entryType` | `IStarPiePlugin` 实现类型全名；留空时宿主可按约定推断 |
| `capabilities` | 插件声明使用的宿主或系统能力 |
| `contributions` | 安装确认页使用的贡献预声明 |
| `dependencies` | 可选，插件间依赖声明 |
| `icon` | 可选，插件图标相对路径 |
| `tags` | 分类标签 |
| `sha256` | 可选，入口程序集完整性摘要 |

字段名称大小写由当前官方宿主按不区分大小写读取，但发布包应统一使用示例中的 camelCase。

## 3. `contributions` 当前语义

当前 SDK 的 `PluginContributions` 包含：

```json
{
  "actions": true,
  "icons": true,
  "i18n": true,
  "styles": false,
  "presets": false
}
```

它用于安装确认页展示和当前宿主的部分交叉校验，不等同于完整的 SPP 调用路径声明。

其中：

- `actions`：提供自定义动作；
- `icons`：注册插件图标；
- `i18n`：注册多语言词条；
- `styles`、`presets`：当前属于预留贡献，宿主可能忽略并提示。

## 4. `paths` 字段状态

`paths` 是 SPP 为动作执行、交互事件和轮盘结构设计的计划字段：

```json
{
  "paths": [
    "action-execution",
    "interaction-event",
    "wheel-structure"
  ]
}
```

但当前官方宿主尚未把 `paths` 作为正式加载条件。插件作者暂时不能仅通过声明 `interaction-event` 或 `wheel-structure` 获得尚未开放的公共能力。

`paths` 正式启用前，需要同步更新：

- `StarPie.Plugin.Abstractions.PluginManifest`；
- `PluginManifestReader`；
- `PluginScanner`；
- 安装确认页；
- 注册会话的路径交叉校验；
- JSON Schema；
- SPP 次版本。

在这些工作完成前，文档和插件包不得把 `paths` 描述为当前宿主已经支持的必填字段。

## 5. 完整 ID 与动作引用

动作描述中的短 ID：

```text
greet
```

插件 ID：

```text
com.example.hello
```

宿主派生完整 ID：

```text
com.example.hello.greet
```

动作配置应分别保存两个字段：

```json
{
  "type": "Plugin",
  "pluginActionRef": {
    "pluginId": "com.example.hello",
    "contributionId": "greet"
  },
  "parameters": {
    "name": "StarPie"
  }
}
```

`FullId` 是运行时派生值，不是唯一持久化来源。显示名称也不能代替 ID。

## 6. 参数配置

插件只声明字段，控件由宿主生成。基础字段包括：

- 文本和多行文本；
- 数字；
- 布尔值；
- 文件和文件夹；
- 枚举；
- 快捷键；
- 颜色。

开发规则：

- 保存和执行使用同一套验证入口；
- 布尔值 `false` 必须显式保存；
- 数值读写使用与区域无关的格式；
- 参数键发布后保持稳定；
- 不得通过参数注入 XAML、控件或可执行代码。

## 7. 插件私有设置

插件私有设置由宿主按插件 ID 隔离。插件通过 `IPluginSettings` 读写，不直接修改 StarPie 主配置。

适合保存：

- 音量和行为选项；
- 缓存版本；
- 用户选择的非敏感插件偏好。

不适合保存：

- 大型 Base64 数据；
- 明文密码和令牌；
- 宿主运行时对象；
- 宿主内部绝对路径。

## 8. 安装与更新

- 扫描到 DLL 只表示发现候选，不应自动执行。
- 安装时必须验证最终加载 DLL 与用户确认 DLL 一致。
- 更新前必须先拒绝新调用、取消并等待活动调用结束。
- 旧插件未完全停止时不得覆盖 DLL；可以要求用户重启后更新。
- 更新应保留插件私有设置和数据。
- 外部开发路径只移除登记，不删除开发者文件。
- 插件系统总开关和应用退出不应清除插件自身的用户启用偏好。

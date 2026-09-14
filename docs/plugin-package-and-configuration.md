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

## 2. plugin.json

建议的最小清单：

```json
{
  "schemaVersion": "1.0",
  "id": "com.example.hello",
  "name": "Hello Plugin",
  "version": "1.0.0",
  "entryAssembly": "HelloPlugin.dll",
  "sppVersion": "1.0",
  "targetFramework": "net8.0-windows10.0.19041.0",
  "architecture": "x64",
  "paths": [
    "action-execution"
  ],
  "capabilities": []
}
```

### 必填字段

| 字段 | 规则 |
|---|---|
| `schemaVersion` | 清单格式版本 |
| `id` | 全局稳定的反向域名 ID，小写 |
| `name` | 默认显示名称 |
| `version` | 插件版本 |
| `entryAssembly` | 包内入口 DLL 相对路径 |
| `sppVersion` | 插件使用的 SPP 主次版本 |
| `targetFramework` | 插件目标框架 |
| `architecture` | `x64` 等宿主支持的架构 |
| `paths` | 插件实现的调用路径 |
| `capabilities` | 需要的宿主能力，可以为空 |

`paths` 可使用：

- `action-execution`
- `interaction-event`
- `wheel-structure`

运行时注册的贡献不能超出清单声明的路径。

wheel-structure 当前属于预留的宿主可选能力。只有宿主明确宣布支持时，插件才能依赖该路径；否则应在执行插件代码前判定为不兼容。

## 3. 完整 ID 与动作引用

动作描述中的短 ID 示例：

```text
greet
```

插件 ID：

```text
com.example.hello
```

宿主生成：

```text
com.example.hello.greet
```

动作配置应保存两个独立字段：

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

`FullId` 是运行时派生值，不是唯一的持久化来源。显示名称也不能代替 ID。

## 4. 参数配置

插件只声明字段，控件由宿主生成。支持的基础字段包括：

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

## 5. 插件私有设置

插件私有设置由宿主按插件 ID 隔离。插件通过上下文读写设置，不直接修改 StarPie 主配置。

私有设置适合保存：

- 音量、行为选项和缓存版本；
- 用户选择的非敏感插件偏好。

不适合保存：

- 大型 Base64 数据；
- 明文密码和令牌；
- 宿主运行时对象或绝对内部路径。

## 6. 安装与更新

- 扫描到 DLL 只表示发现候选，不应自动执行。
- 安装时必须验证最终加载的 DLL 与用户确认的 DLL 一致。
- 更新前先停用并释放旧插件；无法释放文件锁时标记为重启后更新。
- 更新应保留插件私有设置和数据。
- 外部开发路径只移除登记，不删除开发者文件。


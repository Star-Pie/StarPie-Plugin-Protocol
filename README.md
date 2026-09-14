<div align="center">

# StarPie Plugin Protocol（SPP）

*StarPie 进程内 DLL 插件开发规约与实现路线。*

</div>

## 这是什么

SPP 规定 StarPie 如何发现、加载、注册、调用和停用进程内 DLL 插件。本仓库保存协议、开发规则和插件注册表，不包含 SDK 或宿主实现代码。

本文档面向插件开发者、StarPie 宿主开发者，以及为 StarPie 生成代码的 AI。

> [!WARNING]
> DLL 插件与 StarPie 运行在同一进程中，不是安全沙箱。插件异常、死锁和原生崩溃可能影响主程序。

## 三条调用路径

| 路径 | 用途 | 当前状态 | 开发推荐度 |
|---|---|---|---:|
| [动作执行路径](docs/action-execution-path.md) | 执行离散功能并返回结果 | 已有主要调用链，接近可用 | 优先完善 |
| [交互事件路径](docs/interaction-event-path.md) | 接收轮盘会话事件 | 只有初步打开/关闭订阅骨架 | 建议第二阶段实现 |
| [轮盘结构路径](docs/wheel-structure-path.md) | 改变或提供轮盘运行时结构 | 需要拆分出运行时描述对象 | 建议最后实现 |

一个插件可以实现一条或多条路径。路径是贡献能力，不是三种互斥的插件包格式。

## 推荐开发顺序

```text
完善动作执行路径
→ 实现只读交互事件分发
→ 在主程序内部建立轮盘运行时描述对象
→ 实现内部可选的层级轮盘功能
→ 模型稳定后再开放轮盘结构插件
```

交互事件 1.0 只允许观察，不允许修改轮盘核心状态。轮盘结构 1.0 不允许插件提供 WPF 控件、渲染器或命中算法。

## 开发者先读什么

1. [SPP 1.0](docs/SPP-1.0.md)：核心调用模型和公共规则。
2. [插件包与配置](docs/plugin-package-and-configuration.md)：`plugin.json`、完整 ID 和配置持久化。
3. [运行时与生命周期](docs/runtime-and-lifecycle.md)：线程、注册、停用、卸载和错误规则。
4. 阅读目标调用路径的当前状态、问题和实现方向。
5. 发布插件时阅读 [插件注册表与分发](docs/registry-and-distribution.md)。

使用 AI 开发时，还应读取根目录的 [AGENTS.md](AGENTS.md)。

## 核心规则摘要

- 插件只能引用 SDK 契约程序集，不能引用 `StarPie.dll`。
- 插件包不能携带自己的 `StarPie.Plugin.Abstractions.dll`。
- 完整贡献 ID 使用点号组合，例如 `com.example.hello.greet`。
- 配置分别保存 `PluginId` 和 `ContributionId`，不要依赖拆分完整 ID。
- 所有贡献在初始化注册会话中暂存，初始化成功后统一生效。
- 插件不得阻塞输入 Hook、轮盘渲染或交互状态机。
- 插件必须响应取消，并在停用时释放线程、计时器、事件和原生资源。
- 轮盘结构插件只能处理声明式数据；布局、渲染、命中和导航仍由核心负责。

## 仓库结构

```text
StarPie-Plugin-Protocol/
├─ README.md
├─ AGENTS.md
├─ docs/
│  ├─ SPP-1.0.md
│  ├─ plugin-package-and-configuration.md
│  ├─ runtime-and-lifecycle.md
│  ├─ action-execution-path.md
│  ├─ interaction-event-path.md
│  ├─ wheel-structure-path.md
│  └─ registry-and-distribution.md
├─ registry/
│  ├─ index.json
│  └─ plugins/
├─ submissions/
└─ .github/
```

## 状态

当前为 SPP 1.0 设计草案。动作执行路径最接近稳定；交互事件路径处于设计阶段；轮盘结构路径首先作为程序内部可选功能验证，不应立即承诺第三方稳定兼容。

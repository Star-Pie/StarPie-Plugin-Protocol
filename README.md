<div align="center">

# StarPie Plugin Protocol（SPP）

*StarPie 进程内 DLL 插件开发规约与实现路线。*

</div>

## 这是什么

SPP 规定 StarPie 如何发现、加载、注册、调用和停用进程内 DLL 插件。本仓库保存协议规则、插件开发规则、实现状态和插件注册表，不包含 SDK 或宿主实现代码。

本文档面向插件开发者、StarPie 宿主开发者，以及为 StarPie 生成代码的 AI。

> [!WARNING]
> DLL 插件与 StarPie 运行在同一进程中，不是安全沙箱。插件异常、死锁和原生崩溃可能影响主程序。

## 协议与官方实现

本仓库规定“插件与宿主必须遵守什么”，不要求宿主必须使用某个内部类名、锁类型或目录结构。

StarPie 主仓库是 SPP 的官方参考实现。当前实现状态和源码映射见：

- [官方参考实现状态](docs/reference-implementation.md)
- [StarPie 插件系统架构与动作执行路径](https://github.com/SoftBlack42/StarPie/blob/main/docs/plugin-system-architecture.md)

如协议文档与当前宿主实现存在差异，必须明确标注“当前支持”“计划字段”或“参考实现”，不能让插件作者猜测。

## 三条调用路径

| 路径 | 用途 | 当前官方实现状态 | 开发建议 |
|---|---|---|---:|
| [动作执行路径](docs/action-execution-path.md) | 执行离散功能并返回结果 | 注册、惰性加载、参数校验、租约、前后台调度和异步停用已形成基础闭环 | 推荐使用样例进行开发验证 |
| [交互事件路径](docs/interaction-event-path.md) | 接收轮盘会话事件 | 旧 Opening/Closed/Language 回调已接入租约；统一事件队列尚未实现 | 暂缓依赖统一事件能力 |
| [轮盘结构路径](docs/wheel-structure-path.md) | 提供轮盘运行时结构 | 只有宿主内部路径入口和空快照；公共结构契约尚未开放 | 暂不开发第三方插件 |

一个插件可以实现一条或多条路径。路径是贡献能力，不是三种互斥的插件包格式。插件包仍然是加载、停用和卸载单位。

## 推荐开发顺序

```text
补齐动作结果分类、并发策略和压力测试
→ 将 action-execution 标记为 SPP 1.0 稳定路径
→ 实现只读交互事件信封与有界分发队列
→ 在主程序内部建立轮盘运行时描述与快照
→ 模型稳定后再开放第三方 wheel-structure
```

交互事件 1.0 只允许观察，不允许修改轮盘核心状态。轮盘结构 1.0 不允许插件提供 WPF 控件、渲染器或命中算法。

## 开发者先读什么

1. [SPP 1.0](docs/SPP-1.0.md)：核心调用模型和公共规则。
2. [插件包与配置](docs/plugin-package-and-configuration.md)：当前可用的 `plugin.json`、完整 ID 和配置持久化。
3. [运行时与生命周期](docs/runtime-and-lifecycle.md)：线程、租约、停用、卸载和错误规则。
4. 阅读目标调用路径的当前状态、边界和剩余工作。
5. 需要了解官方宿主内部实现时阅读 [参考实现状态](docs/reference-implementation.md)。
6. 发布插件时阅读 [插件注册表与分发](docs/registry-and-distribution.md)。

使用 AI 开发时，还应读取根目录的 [AGENTS.md](AGENTS.md)。

## 核心规则摘要

- 插件只能引用 SDK 契约程序集，不能引用 `StarPie.dll`。
- 插件包不能携带自己的 `StarPie.Plugin.Abstractions.dll`。
- 完整贡献 ID 使用点号组合，例如 `com.example.hello.greet`。
- 配置分别保存 `PluginId` 和 `ContributionId`，不要依赖拆分完整 ID。
- 所有贡献在初始化注册会话中暂存，初始化成功后统一生效。
- 插件不得阻塞输入 Hook、轮盘渲染或交互状态机。
- 活动调用租约由宿主自动管理，插件不手动获取或释放租约。
- `ExecuteAsync` 返回的 Task 必须代表本次动作的真实生命周期。
- 插件应响应取消，并在 `Shutdown` 中释放自建线程、计时器、事件和原生资源。
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
│  ├─ registry-and-distribution.md
│  └─ reference-implementation.md
├─ registry/
│  ├─ index.json
│  └─ plugins/
├─ submissions/
└─ .github/
```

## 状态

当前为 SPP 1.0 设计草案。动作执行路径的官方宿主基础闭环已经完成，但结果分类、并发策略和正式稳定性声明仍待补齐；交互事件路径处于统一模型设计阶段；轮盘结构路径首先作为程序内部能力验证，不应立即承诺第三方稳定兼容。

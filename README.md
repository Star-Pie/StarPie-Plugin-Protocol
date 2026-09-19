<div align="center">

# StarPie Plugin Protocol（SPP）

*StarPie 进程内 DLL 插件协议、开发文档与社区注册表。*

</div>

## 这是什么

SPP 规定 StarPie 如何发现、加载、注册、调用和停用进程内 DLL 插件。本仓库保存：

- SPP 公共协议；
- 第三方插件开发与发布教程；
- StarPie 官方参考实现状态；
- 社区发布者、插件和版本注册表；
- 注册表 Schema、模板、校验工具和自动审核工作流。

本仓库不包含 StarPie 宿主实现代码。

> [!WARNING]
> DLL 插件与 StarPie 运行在同一进程中，不是安全沙箱。插件异常、死锁和原生崩溃可能影响主程序。

## 从哪里开始

### 我是第一次发布插件的开发者

1. [注册第三方发布者](docs/getting-started/publisher-registration.md)
2. [提交第一个社区插件](docs/getting-started/first-plugin-submission.md)
3. [发布插件新版本](docs/getting-started/release-new-version.md)

### 我正在开发插件

- [插件包与配置](docs/development/plugin-package-and-configuration.md)
- [动作执行路径](docs/paths/action-execution.md)
- [运行时与生命周期](docs/protocol/runtime-and-lifecycle.md)

### 我在开发 StarPie 宿主或研究协议

- [SPP 1.0](docs/protocol/SPP-1.0.md)
- [三条能力路径](docs/README.md#三条能力路径)
- [官方参考实现状态](docs/implementation/reference-implementation.md)

### 我在维护社区注册表

- [注册表结构与分发规则](registry/README.md)
- [参与贡献](CONTRIBUTING.md)
- [完整文档导航](docs/README.md)

使用 AI 开发或维护本仓库时还必须阅读 [AGENTS.md](AGENTS.md)。

## 协议与官方实现

本仓库规定“插件与宿主必须遵守什么”，不要求宿主使用某个内部类名、锁类型或目录结构。

StarPie 主仓库是 SPP 的官方参考实现：

- [官方参考实现状态](docs/implementation/reference-implementation.md)
- [StarPie 插件系统架构与动作执行路径](https://github.com/SoftBlack42/StarPie/blob/main/docs/plugin-system-architecture.md)

协议文档与当前宿主实现存在差异时，必须明确标注“当前支持”“计划字段”或“参考实现”。

## 三条调用路径

| 路径 | 用途 | 当前官方实现状态 | 建议 |
|---|---|---|---|
| [动作执行](docs/paths/action-execution.md) | 执行离散功能并返回结果 | 注册、惰性加载、参数校验、租约、调度和异步停用已形成基础闭环 | 推荐优先开发 |
| [交互事件](docs/paths/interaction-events.md) | 接收轮盘会话事件 | 旧回调已接入租约，统一事件队列尚未完成 | 暂缓依赖统一事件能力 |
| [轮盘结构](docs/paths/wheel-structure.md) | 提供轮盘运行时结构 | 只有宿主内部入口和空快照，公共结构契约尚未开放 | 暂不开发第三方插件 |

路径是贡献能力，不是互斥的插件包格式。插件包仍然是加载、停用和卸载单位。

## 核心规则摘要

- 插件只能引用 SDK 契约程序集，不能引用 `StarPie.dll`。
- 插件包不能携带私有 `StarPie.Plugin.Abstractions.dll`。
- 完整贡献 ID 为 `<pluginId>.<contributionId>`。
- 配置分别保存 `PluginId` 和 `ContributionId`。
- 所有贡献在初始化注册会话中暂存，初始化成功后统一生效。
- 插件不得阻塞输入 Hook、轮盘渲染或交互状态机。
- 插件必须响应取消，并在 `Shutdown` 中释放后台任务、线程、计时器、事件和原生资源。
- 轮盘布局、渲染、命中和导航仍由 StarPie 核心负责。

## 仓库结构

```text
StarPie-Plugin-Protocol/
├─ README.md                   # 仓库首页与角色导航
├─ CONTRIBUTING.md             # 贡献流程
├─ AGENTS.md                   # AI 与工程规则
├─ docs/
│  ├─ README.md                # 完整文档导航
│  ├─ getting-started/         # 发布者注册与插件提交教程
│  ├─ development/             # 插件包和配置开发文档
│  ├─ protocol/                # SPP 核心协议与生命周期
│  ├─ paths/                   # 三条能力路径
│  └─ implementation/          # 官方参考实现状态
├─ registry/
│  ├─ README.md                # 注册表结构与维护规则
│  ├─ publishers/              # 发布者登记
│  ├─ plugins/                 # 插件和版本登记
│  └─ generated/               # 生成的社区 catalog
├─ schemas/                    # JSON Schema
├─ templates/                  # 可复制的登记模板
├─ tools/                      # 校验与 catalog 生成工具
└─ .github/                    # PR 模板与自动审核工作流
```

## 当前状态

SPP 1.0 仍处于设计草案阶段。动作执行路径的官方宿主基础闭环已经完成；交互事件路径仍在统一模型设计阶段；轮盘结构路径暂不承诺第三方稳定兼容。

社区注册表 MVP 已提供 GitHub 发布者登记、命名空间所有权、插件与版本记录、静态包校验和确定性 catalog 生成。正式默认启用社区在线安装前，仍需补充 catalog 签名和客户端签名验证。

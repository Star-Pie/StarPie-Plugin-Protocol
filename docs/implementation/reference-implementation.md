# 官方参考实现状态

> 本文件记录 StarPie 官方宿主当前实现到了什么程度，不定义其他 SPP 宿主必须使用的内部类名、锁或目录结构。
>
> 最后更新：2026-09-17

## 1. 协议与实现的关系

```text
StarPie-Plugin-Protocol
→ 规定插件和宿主必须遵守的行为

StarPie.Plugin.Abstractions
→ 当前公开 SDK 契约

StarPie 主仓库
→ SPP 的官方参考实现
```

如果实现类名或内部同步方式变化，但对插件可观察的行为不变，不构成 SPP 协议变化。

## 2. 三条路径状态

| 路径 | 当前官方实现 | 第三方建议 |
|---|---|---:|
| `action-execution` | 基础调用和生命周期闭环已完成 | 可以使用官方样例进行开发验证 |
| `interaction-event` | 旧回调兼容层已接入租约；统一队列未完成 | 暂不依赖新的统一事件能力 |
| `wheel-structure` | 内部路径模块与空快照占位已建立 | 暂不开发第三方结构插件 |

动作路径尚未正式宣告稳定，剩余重点是结果分类、并发策略、健康度维度和真实压力测试。

## 3. 官方宿主公共基础设施

当前 StarPie 主仓库已经实现：

- 独立 SDK 契约程序集；
- 静态 PE 与 manifest 扫描；
- 只读候选目录和可写宿主目录；
- 按插件 ID 管理宿主包装实例；
- 可回收 `AssemblyLoadContext`；
- 初始化期间暂存、成功后原子提交的注册会话；
- 路径注册表；
- 公用激活和惰性加载；
- 按插件实例维护的活动调用租约；
- `Stopping` 门禁和停止取消信号；
- 异步停用与后台继续完成停止；
- 热重载、更新和卸载的安全等待；
- 日志、健康度、熔断和端到端自检。

对应的主要类包括：

| 官方实现类 | 作用 |
|---|---|
| `PluginHost` | 主程序唯一插件门面 |
| `PluginRuntime` | 路径和公共协调器组合根 |
| `PluginInstance` | 单插件运行时包装、状态、锁、租约和 ALC 所有权 |
| `PluginActivationCoordinator` | 插件查找、状态检查和加载 |
| `PluginCallCoordinator` | 进入插件代码前的租约和异常治理入口 |
| `PluginCatalog` | 已提交贡献目录 |
| `PluginRegistrationSession` | Initialize 阶段的暂存注册会话 |
| `ActionExecutionPathModule` | 动作请求、激活、查询、校验和调用语义 |
| `PluginInvoker` | Sequential/Background、超时和结果处理 |

这些类名属于参考实现，不是协议强制要求。

## 4. 动作路径当前能力

```text
ActionItem
→ 不可变 PluginActionRequest
→ 公用激活与惰性加载
→ FullId 查询
→ 声明式参数校验
→ 插件 Validate 租约
→ ExecuteAsync 租约
→ Sequential / Background 调度
→ 超时后继续追踪真实 Task
→ 异步停用等待租约归零
```

官方自检已经覆盖：

- 插件安装后保持未加载；
- 用户禁用状态不触发加载；
- 重启后首次动作惰性加载；
- 参数正反例；
- Background 调用持有租约；
- 停用取消信号；
- `Pending → Stopped`；
- 停止后拒绝新租约；
- ALC 回收和环境还原。

## 5. 当前 manifest 支持

当前官方宿主使用：

```text
schemaVersion
apiVersion
minHostVersion / maxHostVersion
targetFramework
platform
assembly
entryType
capabilities
contributions
dependencies
icon
tags
sha256
```

`paths` 是协议计划字段，当前尚未成为官方宿主正式加载条件。详见 [插件包与配置](../development/plugin-package-and-configuration.md)。

## 6. 参考资料

- [StarPie 主仓库](https://github.com/SoftBlack42/StarPie)
- [插件系统架构与动作执行路径](https://github.com/SoftBlack42/StarPie/blob/main/docs/plugin-system-architecture.md)
- [动作执行路径](../paths/action-execution.md)
- [运行时与生命周期](../protocol/runtime-and-lifecycle.md)

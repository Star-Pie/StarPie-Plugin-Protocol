# SPP 文档与插件开发规则

本文件供参与 StarPie 插件开发的 AI 和开发者使用。开始工作前必须阅读 `README.md`、`docs/SPP-1.0.md`，并阅读目标路径对应的文档。

## 必须遵守

1. SPP 是进程内 DLL 协议，不要把 MCP、JSON-RPC、命名管道或外部进程协议写入 SPP 核心。
2. 插件只允许引用 `StarPie.Plugin.Abstractions` 和宿主允许的框架程序集；不得引用 `StarPie.dll`。
3. 插件构建产物不得包含私有的 `StarPie.Plugin.Abstractions.dll`，否则会产生类型身份分裂。
4. 插件 ID 使用反向域名格式；贡献短 ID 使用契约允许的字母、数字和下划线。
5. 完整 ID 格式是 `<pluginId>.<contributionId>`，例如 `com.example.hello.greet`。
6. 持久化配置分别保存 `PluginId` 和 `ContributionId`；`FullId` 只作为派生查询值。
7. 所有贡献在 `Initialize` 的注册会话中注册。初始化失败时不得留下部分贡献。
8. 所有插件回调都可能发生在非 UI 线程。不得直接操作宿主 WPF 对象。
9. 不得在鼠标/键盘 Hook、轮盘渲染或交互状态机线程调用插件业务代码。
10. 耗时 IO、网络、COM、目录遍历、DDC/CI 等动作必须使用后台调度。
11. 插件必须遵守取消信号和超时约定；超时后不得假设代码已经停止。
12. `Shutdown` 必须停止插件创建的后台任务、线程、计时器和事件订阅，并释放原生资源。
13. 不得依赖强制 Full GC 实现日常卸载。
14. 插件不得提供任意 XAML、WPF 控件或宿主内部对象作为贡献内容。
15. 环境不满足应返回“不可用/拒绝”，不能一律当作插件故障。
16. 轮盘结构公共接口尚未稳定；在内部运行时快照完成前，不得让第三方插件直接依赖 `WheelProfile`、`ActionItem`、`RadialWindow` 或其他宿主内部类型。

## 三条路径

- 动作注册和调用遵守 `docs/action-execution-path.md`。
- 交互事件订阅遵守 `docs/interaction-event-path.md`。
- 动态轮盘结构遵守 `docs/wheel-structure-path.md`。

一个插件可以实现多条路径，但每项贡献必须单独注册。清单中的路径声明必须覆盖运行时注册的全部贡献。

## 修改协议文档时

- 优先写开发者必须遵守的行为，不展开宿主内部类设计。
- 不重复同一规则；通用规则放入 `SPP-1.0.md` 或 `runtime-and-lifecycle.md`。
- 三条路径特有的规则只写入对应路径文档。
- 不根据示例随意修改公共 ID、配置和生命周期语义。
- 协议与当前实现冲突时必须明确记录，不能静默创造迁移格式。
- 稳定行为写入 SPP 正文；当前官方宿主完成度和内部类映射写入 `docs/reference-implementation.md`。
- 协议仓库不得复制主仓库完整内部架构；`PluginInstance`、`PluginCallCoordinator`、锁名和字段名不构成公共契约。
- manifest 示例必须区分“当前宿主已支持字段”和“计划字段”；修改示例前应对照主仓库 `PluginManifest.cs` 与 `samples/HelloAction/plugin.json`。
- `paths` 当前是计划字段，在 SDK、Scanner、ManifestReader 和运行时校验全部接入前，不得描述为当前必填或已支持字段。
- SPP 1.x 内公共规则只增不改；不兼容变化留给新的主版本。

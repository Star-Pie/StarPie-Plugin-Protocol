# 动作执行路径

## 1. 定位与当前状态

动作执行路径处理“用户已经选定一个功能，现在执行它”的请求，例如启动程序、发送快捷键、调整设备状态或调用外部工具。

| 项目 | 结论 |
|---|---|
| 当前成熟度 | 官方宿主已完成基础调用和生命周期闭环 |
| 已完成 | 注册、配置、惰性加载、参数校验、租约、前后台调度、异步停用和自检 |
| 尚待稳定 | 标准结果分类、环境不可用语义、并发策略和更多真实压力测试 |
| 开发建议 | 可以使用官方样例进行动作插件开发验证，正式稳定声明仍待完成 |

当前官方 manifest 通过 `contributions.actions` 预声明动作贡献。计划中的 `paths: ["action-execution"]` 尚未成为当前宿主的正式加载字段。

## 2. 当前官方调用链

```text
插件 Initialize
→ context.Actions.Register(contribution)
→ PluginActionRegistry 校验 ID、描述和参数
→ 注册会话暂存动作
→ Initialize 成功后原子提交到 Catalog
→ 用户配置保存 Type="Plugin" 和 PluginActionRef
→ 轮盘命中后进入 ActionExecutor 单读者动作线程
→ PluginHost 转交 ActionExecutionPathModule
→ 从 ActionItem 复制不可变 PluginActionRequest
→ 根据 PluginId 查找并按需惰性加载插件
→ 加载完成后按 FullId 查询已提交贡献
→ 宿主声明式参数校验
→ 获取校验租约并调用插件 Validate
→ 获取执行租约
→ PluginInvoker 按 Sequential 或 Background 调度
→ 插件返回 ActionResult
→ 任务真实结束后释放租约
→ 宿主记录结果和健康状态
```

动作引用分别保存：

```text
PluginId       = com.example.hello
ContributionId = greet
FullId         = com.example.hello.greet
```

宿主通过注册目录查找贡献，不根据配置反射插件方法。

## 3. 请求快照与惰性加载

动作进入执行路径后，宿主应复制不可变请求，包括：

- `PluginId`；
- `ContributionId`；
- 派生 `FullId`；
- 动作显示名；
- 参数只读快照。

后续加载、校验和执行不再读取可被设置页面修改的原始配置对象。

惰性加载顺序必须是：

```text
根据 PluginId 找到实例
→ 检查用户是否启用
→ 必要时加载并执行 Initialize
→ 提交贡献后再按 FullId 查询动作
```

不得先查询空 Catalog 再决定是否加载，否则程序重启后的第一次调用会错误报告“动作未注册”。

已禁用插件不能被旧动作配置自动重新启用。

## 4. 参数校验

保存动作和执行动作必须复用同一校验实现：

```text
ParameterField 声明式约束
→ 插件 IActionContribution.Validate
```

宿主声明式校验不执行插件代码；插件自定义 `Validate` 属于插件回调，必须纳入活动调用租约。

设置页校验不得为了显示错误而自动加载已卸载插件。执行路径则使用同一个已解析 registration 完成校验和调用，避免两次查询之间插件被停用。

## 5. Sequential

只用于短小且必须保持顺序的操作，例如：

- 发送快捷键；
- 文本输入；
- 前台窗口切换；
- 剪贴板操作。

宿主在唯一动作线程上按顺序等待结果。网络、目录遍历、COM、DDC/CI 等不确定耗时工作不得进入串行动作线程。

如果 Sequential 动作超时但 Task 仍未结束，宿主可以向调用方报告超时，但必须把租约交给后台观察逻辑，直到 Task 真实结束。

## 6. Background

耗时或 IO 动作必须后台执行。调用方可以在任务排队后立即返回“已提交后台执行”，但后台闭包必须继续持有活动调用租约。

```text
取得租约
→ 排入线程池
→ 返回 Queued
→ 后台 ExecuteAsync
→ Task 真实结束
→ finally 释放租约
```

排队成功不等于调用完成。插件停用时，Background 动作应收到取消信号；如果插件不响应，宿主不得提前卸载。

## 7. 当前已经解决的问题

官方宿主已经完成：

- 正确的惰性加载顺序；
- 用户禁用状态与运行时加载分离；
- 同一插件并发首次加载合并；
- 不可变动作请求；
- 保存和执行共用参数校验；
- Validate、Preview 和 ExecuteAsync 的活动租约；
- Sequential 和 Background 一致的停止保护；
- 超时后继续追踪真实 Task；
- `Stopping` 后拒绝新动作；
- 等待活动调用后再 `Shutdown`；
- 热重载、更新和卸载的安全等待；
- 重启后首次惰性调用自检；
- 后台动作执行期间异步停用自检。

## 8. 当前剩余问题

1. **结果类型仍较粗**：公共 `ActionResult` 主要表达成功或失败，尚未正式区分环境不可用、拒绝、取消、超时和插件故障。
2. **环境不可用与故障仍需统一**：设备不支持、权限不足等情况不能错误触发连续失败熔断。
3. **并发策略尚未完整**：同一动作的允许并发、串行、忽略重复、替换旧任务和每插件上限仍需形成宿主规则。
4. **健康度仍偏动作中心**：未来应按 PathId、ContributionId 和结果类型记录。
5. **真实压力测试仍不足**：需要覆盖 COM、DDC/CI、网络、多个并发后台动作以及完全不响应取消的插件。

## 9. 下一步修改方向

### 第一阶段：稳定结果语义

- 在宿主内部先区分 Completed、Rejected、Cancelled、TimedOut、Faulted 和 InvalidResult。
- 不要求插件开发者管理租约或调用计数。
- 公共 SDK 如需扩展结果工厂，必须只增不改并保留旧插件兼容。

### 第二阶段：完善并发策略

- 定义同一动作并发默认值；
- 增加每插件和全局后台任务上限；
- 明确忽略重复和替换旧调用的语义；
- 并发控制由宿主管理，不要求插件自己维护全局锁。

### 第三阶段：压力和兼容验证

- 覆盖多个 Background 动作期间停用；
- 覆盖不响应取消的任务；
- 覆盖热重载和覆盖安装期间的活动调用；
- 验证 ALC、文件锁和内存回收；
- 确认 SDK 不再需要破坏性修改后宣布路径稳定。

## 10. 插件开发规则

- 动作短 ID 发布后保持稳定。
- 参数使用声明式字段，不提供自定义 XAML。
- 布尔值 `false` 必须显式保存，数字使用区域无关格式。
- 环境条件不满足应返回用户可理解的不可用说明，不要一律视为插件故障。
- 耗时动作声明为 Background。
- 插件必须监听取消信号。
- `ExecuteAsync` 返回的 Task 必须代表真实工作，不能启动未跟踪任务后立即返回。
- 超时或取消不等于线程已经被强制终止。
- 插件开发者不获取或释放宿主活动调用租约。

## 11. 官方实现参考

本文件规定动作路径必须满足的行为。StarPie 当前如何通过 `PluginRuntime`、`PluginInstance`、活动调用租约和 `PluginInvoker` 实现这些行为，请参阅：

- [官方参考实现状态](reference-implementation.md)
- [StarPie 插件系统架构与动作执行路径](https://github.com/SoftBlack42/StarPie/blob/main/docs/plugin-system-architecture.md)

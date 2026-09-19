# StarPie Plugin Protocol 文档

本目录保存面向开发者和宿主实现者的人类可读文档。机器校验文件位于 `schemas/`，可复制的数据模板位于 `templates/`，社区注册表维护规则位于 [registry/README.md](../registry/README.md)。

## 第一次发布社区插件

按以下顺序阅读：

1. [注册第三方发布者](getting-started/publisher-registration.md)
2. [提交第一个插件](getting-started/first-plugin-submission.md)
3. [发布插件新版本](getting-started/release-new-version.md)

## 插件开发

- [插件包与配置](development/plugin-package-and-configuration.md)：`.spkg`、`plugin.json`、ID、参数和私有设置。

## SPP 核心协议

- [SPP 1.0](protocol/SPP-1.0.md)：协议范围、分层、注册、调用和兼容原则。
- [运行时与生命周期](protocol/runtime-and-lifecycle.md)：线程、租约、取消、停用和卸载。

## 三条能力路径

- [动作执行](paths/action-execution.md)
- [交互事件](paths/interaction-events.md)
- [轮盘结构](paths/wheel-structure.md)

## 社区注册表

- [注册表结构与分发规则](../registry/README.md)
- [发布者数据目录](../registry/publishers/README.md)
- [插件数据目录](../registry/plugins/README.md)

## 官方参考实现

- [StarPie 官方参考实现状态](implementation/reference-implementation.md)

参考实现用于说明当前 StarPie 已经实现到哪里，不替代 SPP 的公共协议规则。

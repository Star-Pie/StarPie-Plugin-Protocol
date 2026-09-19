# 第三方发布者注册

## 1. 身份模型

社区注册表 MVP 不建立独立账号和密码系统。GitHub 用户身份、Git 历史和 Pull Request 共同构成发布者身份与审计记录。

发布者文件位于：

```text
registry/publishers/github-<GitHub 数字用户 ID>.json
```

创建文件时以 [发布者模板](../../templates/publisher.example.json) 为起点，并符合 [publisher.schema.json](../../schemas/publisher.schema.json)。

## 2. MVP 限制

第一阶段只接受：

- GitHub 个人用户；
- 公开 GitHub 插件仓库；
- `io.github.<login>` 命名空间；
- 由该 GitHub 用户本人发起的首次发布者注册 PR。

GitHub 组织、自定义域名验证和发布者转让将在后续版本单独设计。不要通过修改显示名称模拟所有权转让。

## 3. 发布者 ID 与命名空间

发布者 ID 使用稳定的 GitHub 数字用户 ID：

```text
github:12345678
```

GitHub 登录名用于显示与命名空间：

```text
io.github.example-dev
```

GitHub 用户名发生变化时，发布者 ID 不变。已发布插件 ID 也不得跟随用户名改名。

以下前缀由 StarPie 官方保留，第三方不得注册：

- `starpie.*`
- `com.starpie.*`
- `org.starpie.*`

## 4. 首次注册流程

1. Fork 本仓库。
2. 查询自己的 GitHub 数字用户 ID。
3. 复制 `templates/publisher.example.json`。
4. 保存为 `registry/publishers/github-<userId>.json`。
5. 将 `identity`、`maintainers` 和 `namespaces` 修改为本人信息。
6. 接受当前发布条款版本。
7. 发起发布者注册 PR。

CI 会核对 PR 作者登录名和数字用户 ID。首次注册必须由本人提交，不能由朋友或机器人代交。

## 5. 维护者

`maintainers` 中至少有一名 `owner`，且发布者身份本人必须是 owner。后续插件和版本 PR 的作者必须出现在发布者维护者列表中。

修改已有发布者文件时，授权判断使用目标分支中的旧维护者列表，不能通过同一个 PR 先把自己加入列表再取得权限。

## 6. 安全联系信息

推荐填写 GitHub Security Advisory 地址，不要求公开私人邮箱。安全联系信息用于漏洞报告，不代表 StarPie 官方对插件代码进行过安全审计。

## 7. 状态

发布者状态包括：

- `active`：可以提交插件和版本；
- `suspended`：暂时停止接收新版本；
- `revoked`：身份或行为存在严重问题，停止分发。

状态由社区维护者审核修改，历史文件不得删除。

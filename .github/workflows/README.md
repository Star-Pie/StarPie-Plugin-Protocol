# 工作流目录

社区注册表 MVP 包含两个工作流：

- `validate-registry.yml`：在 PR 中校验发布者身份、插件所有权、注册结构、版本不可变性、生成文件和发生变化的 `.spkg`；
- `publish-community-catalog.yml`：在 main 更新后验证并上传社区 catalog 构建产物。

安全约束：

- Fork PR 不获得发布或签名 Secret；
- PR 校验不会加载或执行插件 DLL；
- 带权限的发布步骤只在合并后的 main 上运行；
- 当前 MVP catalog 构建产物尚未签名，正式默认启用在线安装前必须补充签名与客户端验证。

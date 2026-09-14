# 插件注册信息

此目录保存每个插件的注册信息，一个插件对应一个 JSON 文件：

```text
<pluginId>.json
```

例如：

```text
com.example.hello.json
```

注册信息用于描述插件版本、兼容性、调用路径、Release Asset 下载地址和 SHA-256。实际 `.sppkg` 插件包不提交到此目录，而是上传到本仓库的 GitHub Releases。

新增注册文件后，还必须在上一级 `index.json` 中加入对应插件条目。

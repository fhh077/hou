# V2bX 一键部署仓库

这个仓库只用于公开一键安装脚本和编译好的 V2bX 安装包，不包含 Go 源码。

## 文件结构

```text
scripts/install.sh      # 一键安装脚本
scripts/V2bX.sh         # 安装后的管理菜单
scripts/V2bX.service    # systemd 服务模板
docs/one-click-install.md
dist/V2bX-linux-64.zip  # Linux x86_64 安装包
dist/SHA256SUMS.txt     # 安装包校验值
```

## 一键安装

把 `OWNER/REPO` 换成你的公开仓库名：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/OWNER/REPO/main/scripts/install.sh) --repo OWNER/REPO
```

如果你的公开仓库默认分支是 `master`：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/OWNER/REPO/master/scripts/install.sh) --repo OWNER/REPO --branch master
```

安装脚本会自动完成：

- 下载 `dist/V2bX-linux-64.zip`
- 解压到 `/usr/local/V2bX`
- 生成或保留 `/etc/V2bX/config.json`
- 写入 `/etc/systemd/system/V2bX.service`
- 安装 `/usr/bin/V2bX` 管理脚本
- 执行 `systemctl enable V2bX.service`
- 配置有效时自动启动服务

## 管理命令

```bash
V2bX                 # 打开交互菜单
V2bX config          # 修改配置
V2bX start           # 启动
V2bX stop            # 停止
V2bX restart         # 重启
V2bX status          # 查看状态
V2bX log             # 查看日志
V2bX enable          # 设置开机自启
V2bX disable         # 取消开机自启
V2bX update          # 从 dist/ 重新安装当前公开包
V2bX uninstall       # 卸载
```

详细说明见 [docs/one-click-install.md](docs/one-click-install.md)。

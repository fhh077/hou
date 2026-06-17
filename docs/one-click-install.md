# V2bX 一键安装与管理

本文档对应“公开仓库放安装脚本和编译包，不公开源码”的部署方式。

## 上传到 GitHub 前确认

公开仓库只需要这些内容：

```text
README.md
LICENSE
.gitignore
scripts/
docs/
dist/
```

不要上传 Go 源码目录，例如 `api/`、`cmd/`、`core/`、`node/`、`conf/`、`go.mod`、`go.sum`。

## 安装命令

假设你的公开仓库是 `OWNER/REPO`，默认分支是 `main`：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/OWNER/REPO/main/scripts/install.sh) --repo OWNER/REPO
```

如果默认分支是 `master`：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/OWNER/REPO/master/scripts/install.sh) --repo OWNER/REPO --branch master
```

非交互安装 SSPanel 节点：

```bash
V2BX_PANEL_TYPE=sspanel \
V2BX_API_HOST=https://ss.gpt \
V2BX_API_KEY=你的muKey \
V2BX_NODE_ID=1 \
V2BX_NODE_TYPE=shadowsocks \
V2BX_CORE=sing \
bash <(curl -Ls https://raw.githubusercontent.com/OWNER/REPO/main/scripts/install.sh) --repo OWNER/REPO
```

## 安装包位置

默认下载安装包：

```text
https://raw.githubusercontent.com/OWNER/REPO/main/dist/V2bX-linux-64.zip
```

当前整理目录只生成了 `linux x86_64` 包。如果你的节点服务器是 ARM，需要另外编译并放入：

```text
dist/V2bX-linux-arm64-v8a.zip
```

## 安装后的目录

```text
/usr/local/V2bX/V2bX             # 主程序
/etc/V2bX/config.json            # 配置文件
/etc/systemd/system/V2bX.service # systemd 服务
/usr/bin/V2bX                    # 管理脚本
/usr/bin/v2bx                    # 小写入口
```

## 管理命令

```bash
V2bX
V2bX config
V2bX start
V2bX stop
V2bX restart
V2bX status
V2bX log
V2bX enable
V2bX disable
V2bX update
V2bX uninstall
```

## 手动验证

1. 执行 `V2bX status`，确认服务为 running。
2. 执行 `V2bX log`，确认没有 `401`、`Invalid request`、`unsupported sspanel node sort`。
3. 在面板后台确认节点在线。
4. 使用客户端订阅连接节点，产生流量后确认用户 `u/d` 和在线 IP 更新。
5. 重启服务器后确认 `systemctl is-enabled V2bX` 返回 `enabled`。

# V2bX 一键安装与管理

本文档用于通过公开发布仓库完成 Linux 节点一键安装、开机自启和后续管理。源码保持私有，公开发布仓库只放安装脚本、管理脚本和编译后的 `dist/V2bX-*.zip` 产物。

## 前置条件

- 节点服务器使用 systemd，例如 Debian、Ubuntu、CentOS、Rocky Linux、AlmaLinux。
- 公开发布仓库已经提供 `dist/V2bX-linux-64.zip`、`dist/V2bX-linux-arm64-v8a.zip` 等构建产物，或已经发布包含这些产物的 GitHub Release。
- 如果是 SSPanel，对应面板需要开启 WebAPI，并准备好 `muKey`、节点 ID、节点类型。

## 一键安装

默认公开发布仓库为 `fhh077/hou`，默认分支为 `main`。

```bash
V2BX_REPO=fhh077/hou V2BX_BRANCH=main bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh)
```

也可以直接使用脚本内置默认公开发布源：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh)
```

指定版本：

```bash
V2BX_REPO=fhh077/hou V2BX_BRANCH=main bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh) --version v0.4.0
```

也可以不交互安装，通过环境变量传入节点配置：

```bash
V2BX_REPO=fhh077/hou \
V2BX_BRANCH=main \
V2BX_PANEL_TYPE=sspanel \
V2BX_API_HOST=https://ss.gpt \
V2BX_API_KEY=你的muKey \
V2BX_NODE_ID=1 \
V2BX_NODE_TYPE=shadowsocks \
V2BX_CORE=sing \
bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh)
```

## 安装后的目录

```text
/usr/local/V2bX/V2bX             # V2bX 主程序
/etc/V2bX/config.json            # 运行配置
/etc/systemd/system/V2bX.service # systemd 服务
/usr/bin/V2bX                    # 管理脚本
/usr/bin/v2bx                    # 小写兼容入口
```

安装脚本会执行：

```bash
systemctl enable V2bX.service
```

如果安装时已生成或已有有效配置，会同时尝试启动服务。

服务使用 `Restart=on-failure` 和 `RestartSec=10`。配置错误、核心启动失败等启动错误会以非零状态退出，systemd 会每 10 秒重试；执行 `V2bX stop` 等正常停止不会被自动拉起。这样短暂的面板、网络或端口故障恢复后无需人工启动，同时又不会干扰管理员主动停服。

## 管理命令

```bash
V2bX                 # 打开交互菜单
V2bX config          # 编辑 /etc/V2bX/config.json
V2bX start           # 启动服务
V2bX stop            # 停止服务
V2bX restart         # 重启服务
V2bX status          # 查看服务状态
V2bX enable          # 设置开机自启
V2bX disable         # 取消开机自启
V2bX log             # 查看实时日志
V2bX update          # 更新到最新 Release
V2bX update v0.4.0   # 更新到指定版本
V2bX version         # 查看版本
V2bX uninstall       # 卸载
```

## SSPanel 配置要点

安装脚本首次运行会生成类似配置：

```json
{
  "Nodes": [
    {
      "ApiConfig": {
        "PanelType": "sspanel",
        "ApiHost": "https://ss.gpt",
        "ApiKey": "你的muKey",
        "NodeID": 1,
        "NodeType": "shadowsocks",
        "Timeout": 30
      },
      "Options": {
        "Core": "sing"
      }
    }
  ]
}
```

`NodeType` 对应关系：

- SSPanel `sort=1`：`shadowsocks`
- SSPanel `sort=2`：`tuic`
- SSPanel `sort=11`：`v2ray` 或 `vmess`，如果节点 `custom_config.enable_vless=1` 会按 VLESS 解析
- SSPanel `sort=14`：`trojan`

如果面板开启 `checkNodeIp`，节点服务器出口 IP 必须写入面板节点的 `ipv4` 或 `ipv6`，否则 WebAPI 会返回 401。

## 配置兼容与核心选择

推荐使用上面的 `ApiConfig`、`Options` 嵌套格式。旧版本使用的扁平节点配置仍可读取，不需要为了升级立即改写。

- `Options.Core` 建议明确填写 `xray`、`sing` 或 `hysteria2`，大小写和首尾空格会被规范化。
- 只有一个核心且节点未填写 `Core` 时，会按节点协议自动选择。
- 多个核心都支持同一协议时，不再随机选择，必须填写 `Core`；同类型核心有多个实例时还必须为核心配置 `Name`，并在节点中填写对应的 `CoreName`。
- 未知的 `Core` 会在启动时直接报错，避免拼写错误后悄悄落到另一个核心。

## 证书与私钥文件

Shadowsocks 等不需要 TLS 证书的节点保持 `CertMode: "none"`，不会生成证书或私钥。只有面板节点要求 TLS，且配置了以下模式时才会产生或使用相关文件：

- `self`：在 `CertFile`、`KeyFile` 指定位置生成自签证书和私钥。
- `http` / `dns`：通过 ACME 申请证书，并在证书目录下的 `user/` 保存 ACME 账户文件。
- `file`：只读取用户提供的证书和私钥，不自动生成。

新生成或重新写入的私钥、ACME 账户文件使用 `0600` 权限，证书使用 `0644`。程序不会自动删除已有证书或 ACME 账户；升级前遗留在源码目录的测试证书也不会被当作运行配置使用。

## 日志与故障排查

`Log.Output` 为空时日志进入 systemd journal，可用 `V2bX log` 或 `journalctl -u V2bX` 查看。配置了日志文件但文件无法打开时，程序会记录错误并退回标准错误输出，不会把日志写入无效句柄。

## 手动验证

1. 执行 `V2bX status`，确认服务为 `running`。
2. 执行 `V2bX log`，确认没有 `401`、`Invalid request`、`unsupported sspanel node sort` 或核心选择歧义。
3. 执行 `systemctl show V2bX -p Restart -p RestartUSec`，确认结果为 `on-failure` 和约 10 秒。
4. 在面板后台确认节点在线；使用客户端产生流量后，确认用户 `u/d` 和在线 IP 更新。
5. 修改一次面板下发的拉取/上报间隔或规则并观察日志，确认同步期间连接和流量上报保持正常。默认 systemd 服务使用 `--watch=false`，修改 `/etc/V2bX/config.json` 后应执行 `V2bX restart`；只有自行在启动参数中加入 `--watch` 时才会热重载主配置。
6. 如果使用 `self`、`http` 或 `dns` 证书模式，在 Linux 上执行 `stat -c '%a %n' 私钥路径 ACME账户路径`，确认私有文件为 `600`；`none` 模式应不产生这些文件。
7. 重启服务器后执行 `systemctl is-enabled V2bX` 和 `V2bX status`，确认开机自启生效。

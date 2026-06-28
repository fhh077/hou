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

```bash
bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh)
```

也可以显式指定公开发布仓库：

```bash
V2BX_REPO=fhh077/hou V2BX_BRANCH=main bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh)
```

指定版本安装时，安装脚本会从 GitHub Release 下载对应版本产物：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/fhh077/hou/main/scripts/install.sh) --version v0.4.0
```

不指定版本时，安装脚本会从 `dist/V2bX-当前架构.zip` 下载公开构建产物。

## 安装后管理

```bash
V2bX              # 打开交互菜单
V2bX status       # 查看状态
V2bX log          # 查看实时日志
V2bX errlog       # 查看异常日志
V2bX config       # 修改配置
V2bX restart      # 重启服务
V2bX update       # 更新到 dist 中的最新构建
V2bX update v0.4.0 # 更新到指定 Release 版本
```

## 校验安装包

```bash
cd dist
sha256sum -c SHA256SUMS.txt
```

## 公开边界

- 本仓库只放安装脚本、管理脚本、systemd service、文档和编译后的 zip。
- 私有源码、测试、项目规则、开发脚本和内部配置不应上传到本仓库。

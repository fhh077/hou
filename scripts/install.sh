#!/usr/bin/env bash

set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

DEFAULT_REPO="OWNER/REPO"
DEFAULT_BRANCH="main"
V2BX_REPO="${V2BX_REPO:-$DEFAULT_REPO}"
V2BX_BRANCH="${V2BX_BRANCH:-$DEFAULT_BRANCH}"
INSTALL_VERSION=""

SERVICE_NAME="V2bX"
INSTALL_DIR="/usr/local/V2bX"
CONFIG_DIR="/etc/V2bX"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
MANAGER_FILE="/usr/bin/V2bX"
MANAGER_LINK="/usr/bin/v2bx"

usage() {
    cat <<EOF
V2bX 一键安装脚本

用法:
  bash install.sh --repo owner/repo [--branch master]
  V2BX_REPO=owner/repo bash install.sh

参数:
  --repo       GitHub 仓库，例如 yourname/V2bX
  --branch     脚本和 dist 包所在分支，默认 main
  --version    可选：指定 GitHub Release 版本；不传则从公开仓库 dist/ 下载
  -h, --help   查看帮助
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            V2BX_REPO="${2:-}"
            shift 2
            ;;
        --branch)
            V2BX_BRANCH="${2:-}"
            shift 2
            ;;
        --version)
            INSTALL_VERSION="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            INSTALL_VERSION="$1"
            shift
            ;;
    esac
done

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}错误:${plain} 必须使用 root 用户运行此脚本。"
        exit 1
    fi
}

require_repo() {
    if [[ -z "$V2BX_REPO" || "$V2BX_REPO" == "$DEFAULT_REPO" ]]; then
        echo -e "${red}未配置 GitHub 仓库。${plain}"
        echo "请使用: V2BX_REPO=你的用户名/仓库名 bash install.sh"
        echo "或使用: bash install.sh --repo 你的用户名/仓库名"
        exit 1
    fi
}

require_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "${red}当前系统未检测到 systemd，暂不支持一键安装。${plain}"
        exit 1
    fi
}

install_base() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y curl wget unzip tar ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget unzip tar ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release || true
        yum install -y curl wget unzip tar ca-certificates
    else
        echo -e "${red}未找到 apt-get/dnf/yum，无法自动安装依赖。${plain}"
        exit 1
    fi
}

detect_asset_name() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            echo "linux-64"
            ;;
        i386|i686)
            echo "linux-32"
            ;;
        aarch64|arm64)
            echo "linux-arm64-v8a"
            ;;
        armv7l|armv7*)
            echo "linux-arm32-v7a"
            ;;
        armv6l|armv6*)
            echo "linux-arm32-v6"
            ;;
        armv5l|armv5*)
            echo "linux-arm32-v5"
            ;;
        s390x)
            echo "linux-s390x"
            ;;
        ppc64le)
            echo "linux-ppc64le"
            ;;
        ppc64)
            echo "linux-ppc64"
            ;;
        riscv64)
            echo "linux-riscv64"
            ;;
        mips64le)
            echo "linux-mips64le"
            ;;
        mips64)
            echo "linux-mips64"
            ;;
        mipsle)
            echo "linux-mips32le"
            ;;
        mips)
            echo "linux-mips32"
            ;;
        *)
            echo -e "${red}不支持的系统架构: ${arch}${plain}" >&2
            exit 1
            ;;
    esac
}

download_artifact() {
    local version="$1"
    local asset_name="$2"
    local output="$3"
    local url

    if [[ -n "$version" ]]; then
        url="https://github.com/${V2BX_REPO}/releases/download/${version}/V2bX-${asset_name}.zip"
    else
        url="https://raw.githubusercontent.com/${V2BX_REPO}/${V2BX_BRANCH}/dist/V2bX-${asset_name}.zip"
    fi

    echo "下载: ${url}"
    if ! curl -fL --retry 3 -o "$output" "$url"; then
        echo -e "${red}下载 V2bX 安装包失败，请确认仓库、分支和 dist/V2bX-${asset_name}.zip 是否存在。${plain}"
        exit 1
    fi
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

read_value() {
    local var_name="$1"
    local prompt="$2"
    local default="$3"
    local secret="${4:-false}"
    local value="${!var_name:-}"
    if [[ -n "$value" ]]; then
        printf -v "$var_name" '%s' "$value"
        return
    fi

    if [[ ! -t 0 ]]; then
        printf -v "$var_name" '%s' "$default"
        return
    fi

    if [[ "$secret" == "true" ]]; then
        read -r -s -p "${prompt}${default:+ [默认: $default]}: " value
        echo
    else
        read -r -p "${prompt}${default:+ [默认: $default]}: " value
    fi
    value="${value:-$default}"
    printf -v "$var_name" '%s' "$value"
}

write_config() {
    local panel_type="$1"
    local api_host="$2"
    local api_key="$3"
    local node_id="$4"
    local node_type="$5"
    local core="$6"

    panel_type="$(json_escape "$panel_type")"
    api_host="$(json_escape "$api_host")"
    api_key="$(json_escape "$api_key")"
    node_id="$(json_escape "$node_id")"
    node_type="$(json_escape "$node_type")"
    core="$(json_escape "$core")"

    cat >"$CONFIG_FILE" <<EOF
{
  "Log": {
    "Level": "info",
    "Output": ""
  },
  "Cores": [
    {
      "Type": "${core}",
      "Log": {
        "Level": "info",
        "Timestamp": true
      },
      "NTP": {
        "Enable": false,
        "Server": "time.apple.com",
        "ServerPort": 0
      },
      "OriginalPath": "/etc/V2bX/sing_origin.json"
    }
  ],
  "Nodes": [
    {
      "ApiConfig": {
        "PanelType": "${panel_type}",
        "ApiHost": "${api_host}",
        "ApiKey": "${api_key}",
        "NodeID": ${node_id},
        "NodeType": "${node_type}",
        "Timeout": 30
      },
      "Options": {
        "Core": "${core}",
        "ListenIP": "0.0.0.0",
        "SendIP": "0.0.0.0",
        "DeviceOnlineMinTraffic": 200,
        "ReportMinTraffic": 0,
        "EnableTFO": false,
        "EnableSniff": true,
        "CertConfig": {
          "CertMode": "none"
        }
      }
    }
  ]
}
EOF
    chmod 600 "$CONFIG_FILE"
}

prepare_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "保留现有配置: ${CONFIG_FILE}"
        return 0
    fi

    if [[ ! -t 0 && ( -z "${V2BX_API_HOST:-}" || -z "${V2BX_API_KEY:-}" || -z "${V2BX_NODE_ID:-}" ) ]]; then
        if [[ -f "${INSTALL_DIR}/config.json" ]]; then
            cp "${INSTALL_DIR}/config.json" "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"
        fi
        echo -e "${yellow}非交互环境且缺少 V2BX_API_HOST/V2BX_API_KEY/V2BX_NODE_ID，已写入默认配置但不会自动启动。${plain}"
        return 1
    fi

    local panel_type="${V2BX_PANEL_TYPE:-}"
    local api_host="${V2BX_API_HOST:-}"
    local api_key="${V2BX_API_KEY:-}"
    local node_id="${V2BX_NODE_ID:-}"
    local node_type="${V2BX_NODE_TYPE:-}"
    local core="${V2BX_CORE:-}"

    echo
    echo "首次安装需要生成 /etc/V2bX/config.json"
    read_value panel_type "PanelType，SSPanel 填 sspanel，V2Board 填 v2board" "sspanel"
    read_value api_host "面板地址 ApiHost，例如 https://ss.gpt" ""
    read_value api_key "节点通讯密钥 ApiKey/muKey" "" true
    read_value node_id "节点 ID" ""
    read_value node_type "节点类型，例如 shadowsocks / trojan / v2ray / tuic" "shadowsocks"
    read_value core "核心类型，默认 sing" "sing"

    if [[ -z "$api_host" || -z "$api_key" || -z "$node_id" ]]; then
        echo -e "${red}ApiHost、ApiKey、NodeID 不能为空。${plain}"
        exit 1
    fi
    if ! [[ "$node_id" =~ ^[0-9]+$ ]]; then
        echo -e "${red}NodeID 必须是数字。${plain}"
        exit 1
    fi

    write_config "$panel_type" "$api_host" "$api_key" "$node_id" "$node_type" "$core"
    echo -e "${green}已生成配置: ${CONFIG_FILE}${plain}"
    return 0
}

install_service() {
    cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=V2bX Service
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
User=root
Group=root
Type=simple
LimitNOFILE=999999
WorkingDirectory=/usr/local/V2bX/
ExecStart=/usr/local/V2bX/V2bX server -c /etc/V2bX/config.json
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}.service"
}

install_manager() {
    if [[ -f "${INSTALL_DIR}/scripts/V2bX.sh" ]]; then
        cp "${INSTALL_DIR}/scripts/V2bX.sh" "$MANAGER_FILE"
    else
        curl -fsSL "https://raw.githubusercontent.com/${V2BX_REPO}/${V2BX_BRANCH}/scripts/V2bX.sh" -o "$MANAGER_FILE"
    fi
    sed -i "s|V2BX_REPO_PLACEHOLDER|${V2BX_REPO}|g" "$MANAGER_FILE"
    sed -i "s|V2BX_BRANCH_PLACEHOLDER|${V2BX_BRANCH}|g" "$MANAGER_FILE"
    chmod +x "$MANAGER_FILE"
    ln -sf "$MANAGER_FILE" "$MANAGER_LINK"
}

install_files() {
    local version="$1"
    local asset_name="$2"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    download_artifact "$version" "$asset_name" "${tmp_dir}/V2bX.zip"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
    unzip -oq "${tmp_dir}/V2bX.zip" -d "$INSTALL_DIR"
    chmod +x "${INSTALL_DIR}/V2bX"

    for asset in geoip.dat geosite.dat dns.json route.json custom_inbound.json custom_outbound.json; do
        if [[ -f "${INSTALL_DIR}/${asset}" ]]; then
            cp "${INSTALL_DIR}/${asset}" "${CONFIG_DIR}/${asset}"
        fi
    done

    rm -rf "$tmp_dir"
}

main() {
    require_root
    require_repo
    require_systemd

    local asset_name
    local version
    local should_start=0

    install_base

    asset_name="$(detect_asset_name)"
    version="$INSTALL_VERSION"
    if [[ -n "$version" && "$version" != v* ]]; then
        version="v${version}"
    fi

    if [[ -n "$version" ]]; then
        echo -e "${green}开始安装 V2bX ${version}${plain}"
    else
        echo -e "${green}开始安装 V2bX dist/${asset_name}${plain}"
    fi
    echo "GitHub 仓库: ${V2BX_REPO}"
    echo "系统架构产物: V2bX-${asset_name}.zip"

    install_files "$version" "$asset_name"

    if prepare_config; then
        should_start=1
    fi

    install_service
    install_manager

    if [[ "$should_start" -eq 1 ]]; then
        systemctl restart "${SERVICE_NAME}.service"
        sleep 2
        if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
            echo -e "${green}V2bX 已启动，并已设置开机自启。${plain}"
        else
            echo -e "${red}V2bX 可能启动失败，请使用 V2bX log 查看日志。${plain}"
        fi
    else
        echo -e "${yellow}V2bX 已安装并设置开机自启。请先执行 V2bX config 修改配置，再执行 V2bX start。${plain}"
    fi

    cat <<EOF

管理命令:
  V2bX              打开交互菜单
  V2bX status       查看状态
  V2bX log          查看日志
  V2bX config       修改配置
  V2bX restart      重启服务

EOF
}

main

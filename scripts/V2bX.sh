#!/usr/bin/env bash

set -o pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

SERVICE_NAME="V2bX"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALL_DIR="/usr/local/V2bX"
CONFIG_DIR="/etc/V2bX"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SING_ORIGIN_FILE="${CONFIG_DIR}/sing_origin.json"
BIN_FILE="${INSTALL_DIR}/V2bX"
MANAGER_FILE="/usr/bin/V2bX"
MANAGER_LINK="/usr/bin/v2bx"
V2BX_REPO="${V2BX_REPO:-V2BX_REPO_PLACEHOLDER}"
V2BX_BRANCH="${V2BX_BRANCH:-V2BX_BRANCH_PLACEHOLDER}"

if [[ "$V2BX_REPO" == "V2BX_REPO_PLACEHOLDER" ]]; then
    V2BX_REPO="OWNER/REPO"
fi

if [[ "$V2BX_BRANCH" == "V2BX_BRANCH_PLACEHOLDER" ]]; then
    V2BX_BRANCH="main"
fi

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}错误:${plain} 必须使用 root 用户运行此脚本。"
        exit 1
    fi
}

before_show_menu() {
    echo
    read -r -p "$(echo -e "${yellow}按回车返回主菜单:${plain} ")" _
    show_menu
}

check_installed() {
    [[ -f "$SERVICE_FILE" && -x "$BIN_FILE" ]]
}

check_running() {
    systemctl is-active --quiet "${SERVICE_NAME}.service"
}

check_enabled() {
    systemctl is-enabled --quiet "${SERVICE_NAME}.service" >/dev/null 2>&1
}

ensure_installed() {
    if ! check_installed; then
        echo -e "${red}请先安装 V2bX。${plain}"
        return 1
    fi
    return 0
}

ensure_sing_origin_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ -f "$SING_ORIGIN_FILE" ]]; then
        return 0
    fi

    cat >"$SING_ORIGIN_FILE" <<'EOF'
{}
EOF
    chmod 600 "$SING_ORIGIN_FILE"
}

show_enable_status() {
    if check_enabled; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${yellow}否${plain}"
    fi
}

show_service_status() {
    if ! check_installed; then
        echo -e "V2bX 状态: ${red}未安装${plain}"
        return
    fi
    if check_running; then
        echo -e "V2bX 状态: ${green}已运行${plain}"
    else
        echo -e "V2bX 状态: ${yellow}未运行${plain}"
    fi
    show_enable_status
}

install_url() {
    echo "https://raw.githubusercontent.com/${V2BX_REPO}/${V2BX_BRANCH}/scripts/install.sh"
}

run_installer() {
    local version_arg=""
    local installer_url
    if [[ -n "${1:-}" ]]; then
        version_arg="--version '$1'"
    fi

    if [[ "$V2BX_REPO" == "OWNER/REPO" ]]; then
        echo -e "${red}未配置 GitHub 仓库。${plain}"
        echo "请使用: V2BX_REPO=你的用户名/仓库名 V2bX install"
        return 1
    fi

    installer_url="$(install_url)?$(date +%s)"
    bash -c "bash <(curl -fsSL '${installer_url}') --repo '${V2BX_REPO}' --branch '${V2BX_BRANCH}' ${version_arg}"
}

install_v2bx() {
    run_installer "$1"
    if [[ $? -eq 0 ]]; then
        echo -e "${green}V2bX 安装完成。${plain}"
    fi
}

update_v2bx() {
    local version="${1:-}"
    if [[ -z "$version" ]]; then
        read -r -p "输入指定版本，例如 v0.4.0，留空为最新版本: " version
    fi
    run_installer "$version"
}

edit_config() {
    ensure_installed || return 1
    echo "配置文件: ${CONFIG_FILE}"
    "${EDITOR:-vi}" "$CONFIG_FILE"
    echo
    read -r -p "是否重启 V2bX 使配置生效? [Y/n]: " yn
    yn="${yn:-y}"
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        restart_v2bx
    fi
}

start_v2bx() {
    ensure_installed || return 1
    if check_running; then
        echo -e "${green}V2bX 已运行，无需重复启动。${plain}"
        return 0
    fi
    ensure_sing_origin_config || return 1
    systemctl start "${SERVICE_NAME}.service"
    sleep 2
    if check_running; then
        echo -e "${green}V2bX 启动成功，请使用 V2bX log 查看运行日志。${plain}"
    else
        echo -e "${red}V2bX 可能启动失败，请使用 V2bX log 查看日志。${plain}"
        return 1
    fi
}

stop_v2bx() {
    ensure_installed || return 1
    systemctl stop "${SERVICE_NAME}.service"
    sleep 2
    if check_running; then
        echo -e "${red}V2bX 停止失败，请稍后查看日志。${plain}"
        return 1
    fi
    echo -e "${green}V2bX 停止成功。${plain}"
}

restart_v2bx() {
    ensure_installed || return 1
    ensure_sing_origin_config || return 1
    systemctl restart "${SERVICE_NAME}.service"
    sleep 2
    if check_running; then
        echo -e "${green}V2bX 重启成功。${plain}"
    else
        echo -e "${red}V2bX 可能启动失败，请使用 V2bX log 查看日志。${plain}"
        return 1
    fi
}

status_v2bx() {
    ensure_installed || return 1
    systemctl status "${SERVICE_NAME}.service" --no-pager -l
}

enable_v2bx() {
    ensure_installed || return 1
    systemctl enable "${SERVICE_NAME}.service"
    echo -e "${green}V2bX 已设置开机自启。${plain}"
}

disable_v2bx() {
    ensure_installed || return 1
    systemctl disable "${SERVICE_NAME}.service"
    echo -e "${green}V2bX 已取消开机自启。${plain}"
}

show_log() {
    ensure_installed || return 1
    journalctl -u "${SERVICE_NAME}.service" -e --no-pager -f
}

show_version() {
    ensure_installed || return 1
    "$BIN_FILE" version
}

update_shell() {
    if [[ "$V2BX_REPO" == "OWNER/REPO" ]]; then
        echo -e "${red}未配置 GitHub 仓库，无法更新管理脚本。${plain}"
        return 1
    fi
    curl -fsSL "https://raw.githubusercontent.com/${V2BX_REPO}/${V2BX_BRANCH}/scripts/V2bX.sh" -o "$MANAGER_FILE"
    sed -i "s|V2BX_REPO_PLACEHOLDER|${V2BX_REPO}|g" "$MANAGER_FILE"
    sed -i "s|V2BX_BRANCH_PLACEHOLDER|${V2BX_BRANCH}|g" "$MANAGER_FILE"
    chmod +x "$MANAGER_FILE"
    ln -sf "$MANAGER_FILE" "$MANAGER_LINK"
    echo -e "${green}管理脚本更新完成。${plain}"
}

uninstall_v2bx() {
    ensure_installed || return 1
    read -r -p "确定要卸载 V2bX 吗？这会删除 ${INSTALL_DIR} 和 ${CONFIG_DIR}。[y/N]: " yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
        echo "已取消卸载。"
        return 0
    fi
    systemctl stop "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
    systemctl disable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed
    rm -rf "$CONFIG_DIR" "$INSTALL_DIR"
    rm -f "$MANAGER_FILE" "$MANAGER_LINK"
    echo -e "${green}V2bX 已卸载。${plain}"
}

show_usage() {
    cat <<EOF
V2bX 管理脚本使用方法:
------------------------------------------
V2bX                 显示交互菜单
V2bX install         安装 V2bX
V2bX update [版本]   更新 V2bX；版本留空则从公开仓库 dist/ 下载
V2bX config          编辑配置文件
V2bX start           启动服务
V2bX stop            停止服务
V2bX restart         重启服务
V2bX status          查看服务状态
V2bX enable          设置开机自启
V2bX disable         取消开机自启
V2bX log             查看实时日志
V2bX version         查看版本
V2bX uninstall       卸载 V2bX
V2bX update_shell    更新管理脚本
------------------------------------------
可通过环境变量指定仓库:
V2BX_REPO=owner/repo V2BX_BRANCH=main V2bX install
EOF
}

show_menu() {
    clear
    echo -e "${green}V2bX 后端管理脚本${plain}"
    echo "GitHub 仓库: ${V2BX_REPO}  分支: ${V2BX_BRANCH}"
    echo "------------------------------------------"
    echo -e "${green}0.${plain} 修改配置"
    echo -e "${green}1.${plain} 安装 V2bX"
    echo -e "${green}2.${plain} 更新 V2bX"
    echo -e "${green}3.${plain} 卸载 V2bX"
    echo "------------------------------------------"
    echo -e "${green}4.${plain} 启动 V2bX"
    echo -e "${green}5.${plain} 停止 V2bX"
    echo -e "${green}6.${plain} 重启 V2bX"
    echo -e "${green}7.${plain} 查看状态"
    echo -e "${green}8.${plain} 查看日志"
    echo "------------------------------------------"
    echo -e "${green}9.${plain} 设置开机自启"
    echo -e "${green}10.${plain} 取消开机自启"
    echo -e "${green}11.${plain} 查看版本"
    echo -e "${green}12.${plain} 更新管理脚本"
    echo "------------------------------------------"
    show_service_status
    echo
    read -r -p "请输入选择 [0-12]: " num
    case "$num" in
        0) edit_config; before_show_menu ;;
        1) install_v2bx; before_show_menu ;;
        2) update_v2bx; before_show_menu ;;
        3) uninstall_v2bx; before_show_menu ;;
        4) start_v2bx; before_show_menu ;;
        5) stop_v2bx; before_show_menu ;;
        6) restart_v2bx; before_show_menu ;;
        7) status_v2bx; before_show_menu ;;
        8) show_log ;;
        9) enable_v2bx; before_show_menu ;;
        10) disable_v2bx; before_show_menu ;;
        11) show_version; before_show_menu ;;
        12) update_shell; before_show_menu ;;
        *) echo -e "${red}请输入正确的数字 [0-12]。${plain}"; before_show_menu ;;
    esac
}

require_root

case "${1:-menu}" in
    menu) show_menu ;;
    install) shift; install_v2bx "${1:-}" ;;
    update) shift; update_v2bx "${1:-}" ;;
    config) edit_config ;;
    start) start_v2bx ;;
    stop) stop_v2bx ;;
    restart) restart_v2bx ;;
    status) status_v2bx ;;
    enable) enable_v2bx ;;
    disable) disable_v2bx ;;
    log) show_log ;;
    version) show_version ;;
    uninstall) uninstall_v2bx ;;
    update_shell) update_shell ;;
    help|-h|--help) show_usage ;;
    *) show_usage ;;
esac

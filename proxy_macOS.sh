#!/bin/sh
#
# 在mac端配置xray、proxychains
#   需填入服务端xray的id
# 测试环境：macOS 12.6
#

set -e

# 引用函数
_sh_path="$(cd "$(dirname "${0}")" && pwd)"
# shellcheck disable=SC1091
. "${_sh_path}/function.sh"

# 检查环境
check_env() {
    require_macOS
    install_app_by_pkg_manage gnu-sed
}

# 安装xray
install_xray() {
    install_app_by_pkg_manage xray
}

# 配置xay
config_xray() {
    warn_msg '将会覆盖已存在的xray配置'
    whether_exit
    mkdir -p /usr/local/var/log/xray /usr/local/etc/xray 2>/dev/null || true
    touch /usr/local/var/log/xray/access.log /usr/local/var/log/xray/error.log
    cp "${_sh_path}/xray_conf_client.jsonc" /usr/local/etc/xray/config.json
    printf 'xray服务端域名：'
    read -r web_domain
    printf 'xray服务端uuid：'
    read -r xray_uuid
    sed -i "s/_XRAY_DOMAIN_/${web_domain}/g" /usr/local/etc/xray/config.json
    sed -i "s/_XRAY_UUID_/${xray_uuid}/g" /usr/local/etc/xray/config.json
    brew services restart xray
}

# 客户端xray安装信息
xray_info() {
    printf "xray客户端
通过brew安装
配置文件：/usr/local/etc/xray/config.json
日志文件：/usr/local/var/log/xray/access.log、/usr/local/var/log/xray/error.log
服务开关方式：brew services run/stop xray（brew services restart/start 都会导致开机自启直至执行stop）
查看客户端xray监听的端口：配置文件的/inbounds节点，默认sock5为10800，http为10801
" >"$HOME/xray.txt"
}

# 安装proxychains
conf_proxychains() {
    install_app_by_pkg_manage proxychains-ng
    printf "请将如下信息添加至/usr/local/etc/proxychains.conf的[ProxyList]节点
# socks4...
# xray
socks5  127.0.0.1 10800
http    127.0.0.1 10801
"
    enter_to_continue
    vim /usr/local/etc/proxychains.conf +/\[ProxyList
}

main() {
    node_msg '检查执行环境'
    check_env
    node_msg '安装xray'
    install_xray
    node_msg '配置xray'
    config_xray
    node_msg "将xray配置信息写入 $HOME/xray.txt"
    xray_info
    node_msg '安装proxychains'
    conf_proxychains
    success_msg '执行完成，命令行工具可通过proxychains4使用代理，比如proxychains4 curl www.google.com'
}

main

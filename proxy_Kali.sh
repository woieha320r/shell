#!/bin/sh
#
# 在kali端配置xray、tor、proxychains
#   需填入服务端xray的id
# 测试环境：Kali 2022.3
#

set -e

# 引用函数
_sh_path="$(cd "$(dirname "${0}")" && pwd)"
# shellcheck disable=SC1091
. "${_sh_path}/function.sh"

# 检查执行环境
check_env() {
    require_Linux
    install_app_by_pkg_manage git wget
}

# 安装xray
install_xray() {
    # 如果无法访问github，就export http_proxy=http代理ip:port;export https_proxy=http代理ip:port。或者=socks5://socks代理ip:port
    if [ "$(systemctl list-unit-files | grep -c 'xray.service')" = '0' ]; then
        sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
        # 卸载：# sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
    fi
}

# 配置xay
config_xray() {
    warn_msg '将会覆盖已存在的xray配置'
    whether_exit
    sudo mkdir -p /usr/local/var/log/xray /usr/local/etc/xray 2>/dev/null || true
    sudo touch /usr/local/var/log/xray/access.log /usr/local/var/log/xray/error.log
    sudo chmod a+w /usr/local/var/log/xray/access.log /usr/local/var/log/xray/error.log
    sudo cp "${_sh_path}/xray_conf_client.jsonc" /usr/local/etc/xray/config.json
    printf 'xray服务端域名：'
    read -r web_domain
    printf 'xray服务端uuid：'
    read -r xray_uuid
    sudo sed -i "s/_XRAY_DOMAIN_/${web_domain}/g" /usr/local/etc/xray/config.json
    sudo sed -i "s/_XRAY_UUID_/${xray_uuid}/g" /usr/local/etc/xray/config.json
    sudo systemctl enable xray
    sudo systemctl restart xray
}

# 客户端xray安装信息
client_xray_info() {
    printf "xray客户端
通过brew安装
配置文件：/usr/local/etc/xray/config.json
日志文件：/usr/local/var/log/xray/access.log、/usr/local/var/log/xray/error.log
服务开关方式：brew services run/stop xray（brew services restart/start 都会导致开机自启直至执行stop）
查看客户端xray监听的端口：配置文件的/inbounds节点，默认sock5为10800，http为10801
" >"$HOME/xray.txt"
}

# 配置Tor
# TODO:安装torbrowser-launcher，打开tor browser launcher settings，勾选使用系统tor网络，配置端口为tor端口，点击安装浏览器，打开tor浏览器 -> 设置 -> 高级 -> 配置Tor浏览器联网方式（配置http代理用以连接匿名网络）
config_tor() {
    install_app_by_pkg_manage tor

    printf '控制端口密码：'
    read -r password
    until [ -n "${password}" ]; do
        warn_msg '控制端口密码不可为空'
        printf '控制端口密码：'
        read -r password
    done
    hash_passwd=$(tor --hash-password "${password}")

    # Tor每10分钟更换一次链路，如果要主动请求修改tor链路（出口节点），如下：
    # echo -e "AUTHENTICATE \"9051@tor.ctrl\"\nSIGNAL NEWNYM\nQUIT\n" | nc 127.0.0.1 9051

    [ "$(grep -c 'Tor' /etc/tor/torrc)" != '0' ] || error_msg '未在 /etc/tor/torrc 处找到tor配置文件'
    sudo sed -i 's/^#SocksPort 9050/SocksPort 9050/g' /etc/tor/torrc || true
    sudo sed -i 's/^#ControlPort 9051/ControlPort 9051/g' /etc/tor/torrc || true
    sudo sed -i "s/^#HashedControlPassword.*$/HashedControlPassword ${hash_passwd}/g" /etc/tor/torrc || true
    if [ "$(grep -c '不使用如下政权区域的出口节点' /etc/tor/torrc)" = '0' ]; then
        printf "
## 不使用如下政权区域的出口节点
ExcludeNodes {cn},{hk},{mo},{kp},{ir},{sy},{pk},{cu},{vn}
## 即使无其他可用节点，也仍不使用ExcludeNodes列出的区域
StrictNodes 1

## 将流量导向xray的socks代理端口以连接匿名网络
# HTTPProxy 192.168.0.100:10801
# HTTPSProxy 192.168.0.100:10801
Socks5Proxy 127.0.0.1:10800" | sudo tee -a /etc/tor/torrc
    fi
    sudo systemctl enable tor || true
    sudo systemctl restart tor
}

# 配置proxychains
config_proxychains() {
    install_app_by_pkg_manage proxychains
    # 开启proxy_dns会使DNS也走代理，网上说用的DNS是微软的4.2.2.2，可修改proxyresolv文件自定义，没找到这个文件

    printf "请将如下信息添加至/etc/proxychains4.conf的[ProxyList]节点
# tor
socks4  127.0.0.1 9050
# xray，kali要用tor，不要用xray
# socks5  127.0.0.1 10800
# http    127.0.0.1 10801
"
    enter_to_continue
    sudo vim /etc/proxychains4.conf +/\[ProxyList
}

# 将验证方式写入shell
verify_tor_sh() {
    /bin/cp -f "${_sh_path}/verify_tor.sh" "$HOME/verify_tor.sh"
    chmod 744 "$HOME/verify_tor.sh"
}

# 验证是否连接到tor
verify_tor() {
    sh "$HOME/verify_tor.sh" || error_msg '连接Tor网络失败'
}

tor_info() {
    printf "# 在kali上配合proxychains使用tor\n
tor配置文件：/etc/tor/torrc
tor的开启：tor
tor发布的socks端口：9050
tor发布的控制端口：9051
tor控制端口密码（''内的内容）：'%s'
tor连接依赖的主机上xray发布的socks端口：127.0.0.1:10800
终端应用使用tor依赖于proxychains：proxychains curl https://check.torproject.org/
proxychains配置文件：/etc/proxychains4.conf
proxychains将应用流量导向到tor的端口：9050
" "${password}" >"$HOME/tor.txt"
}

main() {
    node_msg '检查执行环境'
    check_env
    node_msg '安装xray'
    install_xray
    node_msg '配置xray'
    config_xray
    node_msg "将xray配置信息写入 $HOME/xray.txt"
    client_xray_info
    node_msg '配置Tor'
    config_tor
    node_msg '配置proxychains'
    config_proxychains
    node_msg "将验证tor连接状态写入脚本：$HOME/verify_tor.sh"
    verify_tor_sh
    node_msg '等待tor三分钟，它的连接需要时间'
    sleep 180
    node_msg '验证tor连接状态'
    verify_tor
    node_msg "将proxychains、tor信息写入$HOME/tor.txt"
    tor_info
    success_msg '执行完成'
}

main

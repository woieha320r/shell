#!/bin/bash

#*******************************************************************************
# 在kali上安装配置proxychains、tor客户端
#
# Warn：
#   会修改
#
# 完成日期：2022/09/12
#*******************************************************************************

# 全局变量
password=""
hash_passwd=""
xray_client_ip=""
xray_socks_port=""
sh_path=""

# 引用函数
sh_path="$(dirname "$0")"
# shellcheck disable=SC1091
source "${sh_path}/function.sh" 2>/dev/null || {
    echo '需将function.sh放到脚本同级目录'
    exit 1
}

# 检查执行环境
check_env() {
    node_msg '检查执行环境'
    check_os 'Kali GNU/Linux Rolling'
}

# 安装Tor
install_tor() {
    node_msg '安装Tor'
    if ! apt_install_app tor; then
        error_msg 'tor安装失败'
        exit 1
    fi
}

# 获取执行信息
get_info() {
    read -rp "设置控制端口密码：" password
    until [ -n "${password}" ]; do
        warn_msg '控制端口密码不可为空'
        read -rp "设置控制端口密码：" password
    done
    hash_passwd=$(tor --hash-password "${password}")
    read -rp "xray客户端所处IP：" xray_client_ip
    read -rp "xray监听socks的端口：" xray_socks_port
}

# 配置Tor
config_tor() {

    # Tor每10分钟更换一次链路，如果要主动请求修改tor链路（出口节点），如下：
    # echo -e "AUTHENTICATE \"9051@tor.ctrl\"\nSIGNAL NEWNYM\nQUIT\n" | nc 127.0.0.1 9051

    node_msg '配置Tor'
    if [ "$(grep -c 'Tor' /etc/tor/torrc)" == '0' ]; then
        error_msg '未在 /etc/tor/torrc 处找到tor配置文件'
        exit 1
    fi
    sudo sed -i 's/^#SocksPort 9050/SocksPort 9050/g' /etc/tor/torrc
    sudo sed -i 's/^#ControlPort 9051/ControlPort 9051/g' /etc/tor/torrc
    sudo sed -i "s/^#HashedControlPassword.*$/HashedControlPassword ${hash_passwd}/g" /etc/tor/torrc
    if [ "$(grep -c ExcludeNodes /etc/tor/torrc)" == '0' ]; then
        echo -e "
## 不使用如下政权区域的出口节点
ExcludeNodes {cn},{hk},{mo},{kp},{ir},{sy},{pk},{cu},{vn}
## 即使无其他可用节点，也仍不使用ExcludeNodes列出的区域
StrictNodes 1

## 将流量导向xray的socks代理端口以越过GFW连接匿名网络
# HTTPProxy 192.168.0.100:10801
# HTTPSProxy 192.168.0.100:10801
Socks5Proxy ${xray_client_ip}:${xray_socks_port}" | sudo tee -a /etc/tor/torrc
    else
        sudo sed -i "s/^Socks5Proxy.*$/Socks5Proxy ${xray_client_ip}:${xray_socks_port}/g" /etc/tor/torrc
    fi
}

# 安装proxychains
install_proxychains() {
    node_msg '安装proxychains'
    if ! apt_install_app proxychains; then
        error_msg 'proxychains安装失败'
        exit 1
    fi
}

# 配置proxychains
config_proxychains() {

    # 开启proxy_dns会使DNS也走代理，网上说用的DNS是微软的4.2.2.2，可修改proxyresolv文件自定义，没找到这个文件

    node_msg '配置proxychains'
    sudo sed -i 's/^socks4.*$/socks5 127.0.0.1 9050/g' /etc/proxychains4.conf
}

# 验证是否连接到tor
verify_tor() {
    node_msg '验证tor连接状态'
    local curl_res
    if curl_res=$(proxychains curl https://check.torproject.org/) && [ "$(echo -e "${curl_res}" | grep -c 'This browser is configured to use Tor')" != '0' ]; then
        success_msg "连接Tor网络成功：$(echo -e "${curl_res}" | grep 'Your IP address appears to be')"
    else
        error_msg '连接Tor网络失败，结果如上'
        exit 1
    fi
}

# 将验证方式写入shell
verify_tor_sh() {
    node_msg "将验证tor连接状态写入脚本：$HOME/verify_tor.sh"
    echo -e "#!/bin/bash

curl_res=''
if curl_res=\$(proxychains curl https://check.torproject.org/) && [ \"\$(echo -e \"\${curl_res}\" | grep -c 'This browser is configured to use Tor')\" != '0' ]; then
    echo \"连接Tor网络成功：\$(echo -e \"\${curl_res}\" | grep 'Your IP address appears to be')\"
else
    echo '连接Tor网络失败，结果如上'
    exit 1
fi
" >"$HOME/verify_tor.sh"
}

# 结尾提示
end_tip() {
    success_msg "将tor信息写入$HOME/kali_tor.txt"
    echo -e "# 在kali上配合proxychains使用tor\n
tor配置文件：/etc/tor/torrc
tor的开启：tor
tor发布的socks端口：9050
tor发布的控制端口：9051
tor控制端口密码（''内的内容）：'${password}'
tor连接依赖的主机上xray发布的socks端口：${xray_client_ip}:${xray_socks_port}
终端应用使用tor依赖于proxychains：proxychains curl https://check.torproject.org/
proxychains配置文件：/etc/proxychains4.conf
proxychains将应用流量导向到tor的端口：9050" >"$HOME/kali_tor.txt"
}

# 入口函数
main() {
    check_env
    install_tor
    get_info
    config_tor
    install_proxychains
    config_proxychains
    if ! systemctl restart xray || ! systemctl restart tor; then
        error_msg 'xray或tor开启失败'
        exit 1
    fi
    verify_tor
    verify_tor_sh
    end_tip
    success_msg '脚本执行完成'
}

main

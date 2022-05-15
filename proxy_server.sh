#!/bin/sh
#
# 安装配置xray服务端（基于https://xtls.github.io/document/level-0）
#   域名不要加CDN，脚本配置的VLESS+XTLS不支持。VLESS+WS+TLS支持
# 测试环境：Debain 10.2
#
# VPS和域名选购
#   VPS从国外厂商买不用实名；腾讯云的按量付费可关机不收费，还可转弹性公网IP保留IP。国外的比如那个vutrl得销毁实例才不收费
#   域名从国外厂商买不用实名；位于大陆境外的域名解析不用备案
#   Namesilo，域名解析很慢，用cloudflare解析，免费的，还有CDN（cloudflare中叫代理），虽然这里不能用CDN
#       注册cloudflare账号，面板中添加site（域名），得到两个nameserver
#       在namesilo上把域名（domain）的nameserver替换成cloudflare给的那两个，等待邮件通知激活完成
#       在cloudfalre上添加A记录，等会儿就能解析了
#

set -e

# 引用函数
_sh_path="$(cd "$(dirname "${0}")" && pwd)"
# shellcheck disable=SC1091
. "${_sh_path}/function.sh"

# 检查执行环境
check_env() {
    require_Linux
    if [ "$(id -u)" != '0' ] || ! require_not_sudo 2>/dev/null; then
        error_msg '需以root运行，sudo不可'
    fi
    /bin/mv -f /etc/nginx/nginx.conf.bak_by_xray_sh /etc/nginx/nginx.conf 2>/dev/null || true
    install_app_by_pkg_manage host git curl nginx
}

# 获取执行信息
get_info() {
    ip="$(curl ifconfig.me)"
    printf "全域名："
    read -r web_domain

    dns_res="$(host -t A "${web_domain}")"
    [ "$(printf "%s\n" "${dns_res}" | wc -l)" = '1' ] || error_msg "该域名不止一条A记录，如果开启了CDN，请取消\n${dns_res}"
    dns_res="$(printf "%s\n" "${dns_res}" | tr ' ' "\n" | tail -n 1)"
    [ "${ip}" = "${dns_res}" ] || error_msg "域名解析记录[${dns_res}]与脚本执行环境[${ip}]不符"
}

# 获取流量伪装站
get_web() {
    if [ ! -f /var/www/xray_camouflage/index.html ]; then
        if ! git clone https://github.com/Tomotoes/HomePage.git example; then
            error_msg 'git clone 伪装站失败'
        fi
        [ -f example/dist/index.html ] || error_msg '伪装站不再附带编译后的包，请修改脚本'
        mkdir -p /var/www 2>/dev/null || true
        /bin/mv example/dist /var/www/xray_camouflage
        /bin/rm -rf example
    fi
    # 现在还没证书，先不把80重定向到https。证书下载完再解开重定向注释
    [ -f /etc/nginx/nginx.conf.bak_by_xray_sh ] || /bin/cp -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak_by_xray_sh
    if [ "$(grep -c '# xray流量伪装站：' </etc/nginx/nginx.conf)" = '0' ]; then
        sed -i "/^http {/a\\\t# xray流量伪装站：将HTTP重定向到HTTPS（转去访问443）\n\tserver {\n\t\tlisten 80;\n\t\tlisten [::]:80;\n\t\troot /var/www/xray_camouflage/;\n\t\tindex index.html;\n\t\tserver_name ${web_domain};\n\t\t#return 301 https://\$http_host\$request_uri;\n\t}\n\t# nginx并不监听443，由xray负责监听\n\t# xray将非vless协议流量转给如下nginx监听的端口，由其提供网站内容\n\tserver {\n\t\tlisten 127.0.0.1:8080;\n\t\troot /var/www/xray_camouflage/;\n\t\tindex index.html;\n\t\tadd_header Strict-Transport-Security \"max-age=63072000\" always;\n\t}" /etc/nginx/nginx.conf
        systemctl reload nginx
    fi
}

# 安装xray
install_xray() {
    if ! command -v xray >/dev/null 2>&1; then
        wget https://github.com/XTLS/Xray-install/raw/main/install-release.sh
        bash install-release.sh
        /bin/rm -rf install-release.sh
        mkdir -p /var/log/xray /usr/local/etc/xray 2>/dev/null || true
        touch /var/log/xray/access.log /var/log/xray/error.log
        chmod a+w /var/log/xray/*.log
    fi
    xray_uuid="$(xray uuid)"
    cp "${_sh_path}/xray_conf_server.jsonc" /usr/local/etc/xray/config.json
    sed -i "s/_XRAY_UUID_/${xray_uuid}/g" /usr/local/etc/xray/config.json
}

# 测试获取tls证书
get_tls_cert() {
    if [ ! -f /etc/cert/xray_camouflage/key.pem ] && [ ! -f /etc/cert/xray_camouflage/fullchain.pem ]; then
        # 测试获取
        if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
            wget -O - https://get.acme.sh | sh
            "$HOME/.acme.sh/acme.sh" --upgrade --auto-upgrade
        fi
        if ! "$HOME/.acme.sh/acme.sh" --issue --server letsencrypt --test -d "${web_domain}" -w /var/www/xray_camouflage --keylength ec-256; then
            warn_msg "测试获取tls证书失败，不一定影响执行。执行如下命令查看debug信息：$HOME/.acme.sh/acme.sh --issue --server letsencrypt --test -d ${web_domain} -w /var/www/xray_camouflage --keylength ec-256 --debug"
            whether_exit
        fi
        # 正式获取
        mkdir -p /etc/cert/xray_camouflage 2>/dev/null || true
        if ! "$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt || ! "$HOME/.acme.sh/acme.sh" --issue -d "${web_domain}" -w /var/www/xray_camouflage --keylength ec-256 --force; then
            error_msg '正式证书申请失败，或因次数过多'
        fi
        # reloadcmd的命令现在必须可执行，否则执行失败，但证书已被安装
        if ! "$HOME/.acme.sh/acme.sh" --installcert -d "${web_domain}" --key-file /etc/cert/xray_camouflage/key.pem --fullchain-file /etc/cert/xray_camouflage/fullchain.pem --ecc --reloadcmd 'systemctl reload nginx;systemctl restart xray'; then
            error_msg '正式证书申请失败，或因次数过多，或reloadcmd无法执行'
        fi
    else
        warn_msg '站点证书已存在，是否重新获取 [y/others]: '
        read -r _any_str
        if [ "${_any_str}" = 'y' ]; then
            /bin/rm -rf /etc/cert/xray_camouflage/key.pem /etc/cert/xray_camouflage/fullchain.pem
            get_tls_cert
        else
            systemctl reload nginx
            systemctl restart xray
        fi
    fi
    chmod +r /etc/cert/xray_camouflage/key.pem
    # 证书安装完成，让nginx将80的流量重定向到https
    sed -i 's/#return 301 https/return 301 https/g' /etc/nginx/nginx.conf || true
}

# 安装bbr
install_bbr() {
    need_reboot="false"
    if [ "$(lsmod | grep -c 'bbr')" = '0' ]; then
        printf "deb http://deb.debian.org/debian buster-backports main" >>/etc/apt/sources.list.d/self.list
        printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/self.conf
        apt update >/dev/null
        apt -t buster-backports install linux-image-amd64 -y >/dev/null
        need_reboot="true"
    fi
}

# 配置服务自启
autostart_services() {
    systemctl enable nginx
    systemctl reload nginx
    systemctl enable xray
    systemctl restart xray
}

# 结尾提示
xray_info() {
    printf "xray服务器\n
流量伪装站根目录：/var/www/xray_camouflage
tls证书安装目录：/etc/cert/xray_camouflage/fullchain.pem、/etc/cert/xray_camouflage/key.pem
日志文件：/var/log/xray/access.log、/var/log/xray/error.log
配置文件：/usr/local/etc/xray/config.json
全域名：%s
端口：443
协议：VLESS、XTLS
UUID（由脚本自动生成于%s）：%s
" "${web_domain}" "$(date '+%Y-%m-%d %H:%M:%S')" "${xray_uuid}" >"$HOME/xray.txt"
}

# 入口函数
main() {
    node_msg '检查执行环境'
    check_env
    node_msg '获取执行信息'
    get_info
    node_msg '部署流量伪装站'
    get_web
    node_msg '安装xray'
    install_xray
    node_msg '获取tls证书'
    get_tls_cert
    node_msg '安装BBR'
    install_bbr
    node_msg '配置服务自启'
    autostart_services
    node_msg "将xray服务端信息写入 $HOME/xray.txt"
    xray_info
    success_msg '执行完成'
    [ "${need_reboot}" != "true" ] || warn_msg '需重启服务器'
}

main

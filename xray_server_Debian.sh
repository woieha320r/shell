#!/bin/bash

#*******************************************************************************
# 安装配置xray服务端（https://xtls.github.io/document/level-0）
#
# 域名不要加CDN，脚本配置的VLESS+XTLS不支持。VLESS+WS+TLS支持
#
# Warn：
#   脚本运行完成会重启服务器
#   脚本会修改/var/www/xray_camouflage、/etc/nginx/nginx.conf、/etc/cert/xray_camouflage
#       /var/log/xray/access.log /var/log/xray/error.log、/var/log/xray/*.log
#       /etc/apt/sources.list.d/self.list、/etc/sysctl.d/self.conf
#
# VPS和域名选购
#   VPS从国外厂商买不用实名；但腾讯云的按量付费可关机不收费，还可转弹性公网IP保留IP。但国外的比如那个vutrl得销毁实例才不收费
#   域名从国外厂商买不用实名；位于大陆境外的域名解析不用备案
#   选的Namesilo，域名解析很慢，用cloudflare解析，免费的，还有CDN（cloudflare中叫代理），虽然这里不能用CDN
#       注册cloudflare账号，面板中添加site（域名），得到两个nameserver
#       在namesilo上把域名（domain）的nameserver替换成cloudflare给的那两个，等待邮件通知激活完成
#       在cloudfalre上添加A记录，等会儿就能解析了
#
# 完成日期：2022/09/12
#*******************************************************************************

# 全局变量
web_domain=""
xray_uuid=""
ip=""
need_reboot=""
sh_path=""

# 引用函数
sh_path="$(dirname "$0")"
# shellcheck disable=SC1091
source "${sh_path}/function.sh" 2>/dev/null || {
    echo '需将function.sh放到脚本同级目录'
    exit 1
}

# 打印失败提示并回退nginx配置
error_and_rollback_nginx() {
    error_msg "$1"
    [ -f /etc/nginx/nginx.conf.bak_by_xray_sh ] && mv /etc/nginx/nginx.conf.bak_by_xray_sh /etc/nginx/nginx.conf
    return 0
}

# 检查执行环境
check_env() {
    node_msg '检查执行环境'
    warn_msg '需以root身份运行，非sudo'
    whether_exit
    check_os 'Debian GNU/Linux 10'
    [ -f /etc/nginx/nginx.conf.bak_by_xray_sh ] && mv /etc/nginx/nginx.conf.bak_by_xray_sh /etc/nginx/nginx.conf
    apt_install_app host git curl nginx
}

# 获取执行信息
get_info() {
    node_msg '获取执行信息'

    ip="$(curl ifconfig.me)"

    read -rp '全域名：' web_domain

    local dns_res
    dns_res=$(host -t A "${web_domain}")
    if [ "$(echo -e "${dns_res}" | wc -l)" != '1' ]; then
        error_and_rollback_nginx "该域名不止一条A记录，如果开启了CDN，请取消\n${dns_res}"
        exit 1
    fi
    dns_res="$(echo "${dns_res}" | tr ' ' "\n" | tail -n 1)"
    if [ "${ip}" != "${dns_res}" ]; then
        error_and_rollback_nginx "域名解析记录[${dns_res}]与脚本执行环境[${ip}]不符"
        exit 1
    fi

}

# 获取流量伪装站
get_web() {
    node_msg '部署流量伪装站'
    if [ ! -f /var/www/xray_camouflage/index.html ]; then
        if ! git clone https://github.com/Tomotoes/HomePage.git example; then
            error_and_rollback_nginx 'git clone 伪装站失败'
            exit 1
        fi
        if [ ! -f example/dist/index.html ]; then
            error_and_rollback_nginx '伪装站不再附带编译后的包，请修改脚本'
            exit 1
        fi
        [ ! -d /var/www ] && mkdir -p /var/www
        mv example/dist /var/www/xray_camouflage
        /bin/rm -rf example
    fi
    # 现在还没证书，先不把80重定向到https。证书下载完再解开重定向注释
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak_by_xray_sh
    if [ "$(grep -c '# xray流量伪装站：' </etc/nginx/nginx.conf)" == '0' ]; then
        sed -i "/^http {/a\\\t# xray流量伪装站：将HTTP重定向到HTTPS（转去访问443）\n\tserver {\n\t\tlisten 80;\n\t\tlisten [::]:80;\n\t\troot /var/www/xray_camouflage/;\n\t\tindex index.html;\n\t\tserver_name ${web_domain};\n\t\t#return 301 https://\$http_host\$request_uri;\n\t}\n\t# nginx并不监听443，由xray负责监听\n\t# xray将非vless协议流量转给如下nginx监听的端口，由其提供网站内容\n\tserver {\n\t\tlisten 127.0.0.1:8080;\n\t\troot /var/www/xray_camouflage/;\n\t\tindex index.html;\n\t\tadd_header Strict-Transport-Security \"max-age=63072000\" always;\n\t}" /etc/nginx/nginx.conf
        systemctl reload nginx
    fi
}

# 测试获取tls证书
get_tls_cert_test() {
    node_msg '测试获取tls证书'
    if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
        wget -O - https://get.acme.sh | sh
        "$HOME/.acme.sh/acme.sh" --upgrade --auto-upgrade
    fi
    if [ ! -f /etc/cert/xray_camouflage/key.pem ] && [ ! -f /etc/cert/xray_camouflage/fullchain.pem ]; then
        if ! "$HOME/.acme.sh/acme.sh" --issue --server letsencrypt --test -d "${web_domain}" -w /var/www/xray_camouflage --keylength ec-256; then
            error_and_rollback_nginx '测试获取tls证书失败，如下是debug信息：'
            "$HOME/.acme.sh/acme.sh" --issue --server letsencrypt --test -d "${web_domain}" -w /var/www/xray_camouflage --keylength ec-256 --debug
            exit 1
        fi
    fi
}

# 正式获取tls证书
get_tls_cert() {
    node_msg '正式获取tls证书'
    if [ ! -f /etc/cert/xray_camouflage/key.pem ] && [ ! -f /etc/cert/xray_camouflage/fullchain.pem ]; then
        mkdir -p /etc/cert/xray_camouflage 2>/dev/null
        if ! "$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt; then
            error_and_rollback_nginx '正式证书申请失败，或因次数过多'
            exit 1
        fi
        if ! "$HOME/.acme.sh/acme.sh" --issue -d "${web_domain}" -w /var/www/xray_camouflage --keylength ec-256 --force; then
            error_and_rollback_nginx '正式证书申请失败，或因次数过多'
            exit 1
        fi
        # reloadcmd的命令现在必须可执行，否则执行失败，但证书已被安装
        if ! "$HOME/.acme.sh/acme.sh" --installcert -d "${web_domain}" --key-file /etc/cert/xray_camouflage/key.pem --fullchain-file /etc/cert/xray_camouflage/fullchain.pem --ecc --reloadcmd 'systemctl reload nginx;systemctl restart xray'; then
            error_and_rollback_nginx '正式证书申请失败，或因次数过多或reloadcmd无法执行'
            exit 1
        fi
    else
        systemctl reload nginx
        systemctl restart xray
    fi
    chmod +r /etc/cert/xray_camouflage/key.pem
    # 证书安装完成，让nginx将80的流量重定向到https
    sed -i 's/#return 301 https/return 301 https/g' /etc/nginx/nginx.conf
}

# 安装xray
install_xray() {
    node_msg '安装xray'
    if ! which xray >/dev/null 2>&1; then
        wget https://github.com/XTLS/Xray-install/raw/main/install-release.sh
        bash install-release.sh
        /bin/rm -rf install-release.sh
        mkdir -p /var/log/xray /usr/local/etc/xray 2>/dev/null
        touch /var/log/xray/access.log /var/log/xray/error.log
        chmod a+w /var/log/xray/*.log
    fi
    xray_uuid="$(xray uuid)"
    echo -e "// REFERENCE:
// https://github.com/XTLS/Xray-examples
// https://xtls.github.io/config/
// 常用的 config 文件，不论服务器端还是客户端，都有 5 个部分。外加小小白解读：
// ┌─ 1_log 日志设置 - 日志写什么，写哪里（出错时有据可查）
// ├─ 2_dns DNS-设置 - DNS 怎么查（防 DNS 污染、防偷窥、避免国内外站匹配到国外服务器等）
// ├─ 3_routing 分流设置 - 流量怎么分类处理（是否过滤广告、是否国内外分流）
// ├─ 4_inbounds 入站设置 - 什么流量可以流入 Xray
// └─ 5_outbounds 出站设置 - 流出 Xray 的流量往哪里去
{
    // 1_日志设置
    \"log\": {
        \"loglevel\": \"warning\", // 内容从少到多: \"none\", \"error\", \"warning\", \"info\", \"debug\"
        \"access\": \"/var/log/xray/access.log\", // 访问记录
        \"error\": \"/var/log/xray/error.log\" // 错误记录
    },
    // 2_DNS设置
    \"dns\": {
        \"servers\": [
            \"https+local://1.1.1.1/dns-query\", // 首选 1.1.1.1 的 DoH 查询，牺牲速度但可防止 ISP 偷窥
            \"localhost\"
        ]
    },
    // 3_分流设置
    \"routing\": {
        \"domainStrategy\": \"AsIs\",
        \"rules\": [
            // 3.1 防止服务器本地流转问题：如内网被攻击或滥用、错误的本地回环等
            {
                \"type\": \"field\",
                \"ip\": [
                    \"geoip:private\" // 分流条件：geoip 文件内，名为\"private\"的规则（本地）
                ],
                \"outboundTag\": \"block\" // 分流策略：交给出站\"block\"处理（黑洞屏蔽）
            },
            // 3.2 屏蔽广告
            {
                \"type\": \"field\",
                \"domain\": [
                    \"geosite:category-ads-all\" // 分流条件：geosite 文件内，名为\"category-ads-all\"的规则（各种广告域名）
                ],
                \"outboundTag\": \"block\" // 分流策略：交给出站\"block\"处理（黑洞屏蔽）
            }
        ]
    },
    // 4_入站设置
    // 4.1 这里只写了一个最简单的 vless+xtls 的入站，因为这是 Xray 最强大的模式。如有其他需要，请根据模版自行添加。
    \"inbounds\": [
        {
            \"port\": 443,
            \"protocol\": \"vless\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"${xray_uuid}\", // 填写你的 UUID
                        \"flow\": \"xtls-rprx-direct\",
                        \"level\": 0,
                        \"email\": \"\"
                    }
                ],
                \"decryption\": \"none\",
                \"fallbacks\": [
                    {
                        \"dest\": 8080 // 默认回落到防探测的代理
                    }
                ]
            },
            \"streamSettings\": {
                \"network\": \"tcp\",
                \"security\": \"xtls\",
                \"xtlsSettings\": {
                    \"allowInsecure\": false, // 正常使用应确保关闭
                    \"minVersion\": \"1.2\", // TLS 最低版本设置
                    \"alpn\": [
                        \"http/1.1\"
                    ],
                    \"certificates\": [
                        {
                            \"certificateFile\": \"/etc/cert/xray_camouflage/fullchain.pem\",
                            \"keyFile\": \"/etc/cert/xray_camouflage/key.pem\"
                        }
                    ]
                }
            }
        }
    ],
    // 5*出站设置
    \"outbounds\": [
        // 5.1 第一个出站是默认规则，freedom 就是对外直连（vps 已经是外网，所以直连）
        {
            \"tag\": \"direct\",
            \"protocol\": \"freedom\"
        },
        // 5.2 屏蔽规则，blackhole 协议就是把流量导入到黑洞里（屏蔽）
        {
            \"tag\": \"block\",
            \"protocol\": \"blackhole\"
        }
    ]
}" >/usr/local/etc/xray/config.json
}

# 安装bbr
install_bbr() {
    node_msg '安装BBR'
    need_reboot="false"
    if [ "$(lsmod | grep -c 'bbr')" == '0' ]; then
        echo 'deb http://deb.debian.org/debian buster-backports main' >>/etc/apt/sources.list.d/self.list
        echo -e 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr' >>/etc/sysctl.d/self.conf
        apt update
        apt -t buster-backports install linux-image-amd64 -y
        need_reboot="true"
    fi
}

# 配置服务自启
autostart_services() {
    node_msg '配置服务自启'
    systemctl enable nginx
    systemctl reload nginx
    systemctl enable xray
    systemctl restart xray
}

# 结尾提示
end_tip() {
    node_msg "将xray服务端信息写入 $HOME/xray_server.txt"
    echo -e "xray服务器\n
流量伪装站根目录：/var/www/xray_camouflage
tls证书安装目录：/etc/cert/xray_camouflage/fullchain.pem、/etc/cert/xray_camouflage/key.pem
日志文件：/var/log/xray/access.log、/var/log/xray/error.log
配置文件：/usr/local/etc/xray/config.json
全域名：${web_domain}
端口：443
协议：VLESS、XTLS
UUID（由脚本自动生成于$(date '+%Y/%m/%d %H:%M:%S')）：${xray_uuid}" >"$HOME/xray_server.txt"
}

# 入口函数
main() {
    check_env
    get_info
    get_web
    get_tls_cert_test
    install_xray
    get_tls_cert
    install_bbr
    autostart_services
    end_tip
    success_msg '脚本执行完成'
    [ "${need_reboot}" == "true" ] && warn_msg '需重启服务器'
}

main

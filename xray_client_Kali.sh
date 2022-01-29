#!/bin/bash

#*******************************************************************************
# 在kali端安装配置xray客户端
#
# Warn：
#   会修改/usr/local/etc/xray/config.json、/var/log/xray/{access.log, error.log}
#
# 完成日期：2022/09/12
#*******************************************************************************

# 全局变量
web_domain=""
xray_uuid=""
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
    if ! apt_install_app git wget; then
        error_msg '软件安装失败'
        exit 1
    fi
}

# 安装xray
install_xray() {
    node_msg '安装xray'
    if [ "$(systemctl list-unit-files | grep -c 'xray.service')" == '0' ]; then
        if ! sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
            error_msg 'xray安装脚本执行失败'
            exit 1
        fi
        # 卸载：# sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
    fi
    systemctl enable xray
}

# 获取执行信息
get_info() {
    node_msg '获取执行信息'
    read -rp 'xray服务端域名：' web_domain
    read -rp 'xray服务端uuid：' xray_uuid
}

# 配置xay
config_xray() {
    node_msg '配置xray'
    sudo mkdir -p /var/log/xray /usr/local/etc/xray
    sudo touch /var/log/xray/access.log /var/log/xray/error.log
    sudo chmod a+w /var/log/xray/access.log /var/log/xray/error.log
    mkdir -p /usr/local/etc/xray
    echo -e "// REFERENCE:
// https://github.com/XTLS/Xray-examples
// https://xtls.github.io/config/
// 常用的config文件，不论服务器端还是客户端，都有5个部分。外加小小白解读：
// ┌─ 1_log          日志设置 - 日志写什么，写哪里（出错时有据可查）
// ├─ 2_dns          DNS-设置 - DNS怎么查（防DNS污染、防偷窥、避免国内外站匹配到国外服务器等）
// ├─ 3_routing      分流设置 - 流量怎么分类处理（是否过滤广告、是否国内外分流）
// ├─ 4_inbounds     入站设置 - 什么流量可以流入Xray
// └─ 5_outbounds    出站设置 - 流出Xray的流量往哪里去
{
    // 1_日志设置
    // 注意，本例中我默认注释掉了日志文件，因为windows, macOS, Linux 需要写不同的路径，请自行配置
    \"log\": {
        \"access\": \"/var/log/xray/access.log\",    // 访问记录
        \"error\": \"/var/log/xray/error.log\",    // 错误记录
        \"loglevel\": \"warning\" // 内容从少到多: \"none\", \"error\", \"warning\", \"info\", \"debug\"
    },
    // 2_DNS设置
    \"dns\": {
        \"servers\": [
            // 2.1 国外域名使用国外DNS查询
            {
                \"address\": \"1.1.1.1\",
                \"domains\": [
                    \"geosite:geolocation-!cn\"
                ]
            },
            // 2.2 国内域名使用国内DNS查询，并期待返回国内的IP，若不是国内IP则舍弃，用下一个查询
            {
                \"address\": \"223.5.5.5\",
                \"domains\": [
                    \"geosite:cn\"
                ],
                \"expectIPs\": [
                    \"geoip:cn\"
                ]
            },
            // 2.3 作为2.2的备份，对国内网站进行二次查询
            {
                \"address\": \"114.114.114.114\",
                \"domains\": [
                    \"geosite:cn\"
                ]
            },
            // 2.4 最后的备份，上面全部失败时，用本机DNS查询
            \"localhost\"
        ]
    },
    // 3_分流设置
    // 所谓分流，就是将符合否个条件的流量，用指定tag的出站协议去处理（对应配置的5.x内容）
    \"routing\": {
        \"domainStrategy\": \"IPIfNonMatch\",
        \"rules\": [
            // 3.1 广告域名屏蔽
            {
                \"type\": \"field\",
                \"domain\": [
                    \"geosite:category-ads-all\"
                ],
                \"outboundTag\": \"block\"
            },
            // 3.2 国内域名直连
            {
                \"type\": \"field\",
                \"domain\": [
                    \"geosite:cn\"
                ],
                \"outboundTag\": \"direct\"
            },
            // 3.3 国内IP直连
            {
                \"type\": \"field\",
                \"ip\": [
                    \"geoip:cn\",
                    \"geoip:private\"
                ],
                \"outboundTag\": \"direct\"
            },
            // 3.4 国外域名代理
            {
                \"type\": \"field\",
                \"domain\": [
                    \"geosite:geolocation-!cn\"
                ],
                \"outboundTag\": \"proxy\"
            },
            // 3.5 默认规则
            // 在Xray中，任何不符合上述路由规则的流量，都会默认使用【第一个outbound（5.1）】的设置，所以一定要把转发VPS的outbound放第一个
            // 3.6 走国内\"223.5.5.5\"的DNS查询流量分流走direct出站
            {
                \"type\": \"field\",
                \"ip\": [
                    \"223.5.5.5\"
                ],
                \"outboundTag\": \"direct\"
            }
        ]
    },
    // 4_入站设置
    \"inbounds\": [
        // 4.1 一般都默认使用socks5协议作本地转发
        {
            \"tag\": \"socks-in\",
            \"protocol\": \"socks\",
            \"listen\": \"0.0.0.0\", // 这个是通过socks5协议做本地转发的地址
            \"port\": 10800, // 这个是通过socks5协议做本地转发的端口
            \"settings\": {
                \"udp\": true
            }
        },
        // 4.2 有少数APP不兼容socks协议，需要用http协议做转发，则可以用下面的端口
        {
            \"tag\": \"http-in\",
            \"protocol\": \"http\",
            \"listen\": \"0.0.0.0\", // 这个是通过http协议做本地转发的地址
            \"port\": 10801 // 这个是通过http协议做本地转发的端口
        }
    ],
    // 5_出站设置
    \"outbounds\": [
        // 5.1 默认转发VPS
        // 一定放在第一个，在routing 3.5 里面已经说明了，这等于是默认规则，所有不符合任何规则的流量都走这个
        {
            \"tag\": \"proxy\",
            \"protocol\": \"vless\",
            \"settings\": {
                \"vnext\": [
                    {
                        \"address\": \"${web_domain}\", // 替换成你的真实域名
                        \"port\": 443,
                        \"users\": [
                            {
                                \"id\": \"${xray_uuid}\", // 和服务器端的一致
                                \"flow\": \"xtls-rprx-direct\", // Windows, macOS 同学保持这个不变
                                // \"flow\": \"xtls-rprx-splice\",    // Linux和安卓同学请改成Splice性能更强
                                \"encryption\": \"none\",
                                \"level\": 0
                            }
                        ]
                    }
                ]
            },
            \"streamSettings\": {
                \"network\": \"tcp\",
                \"security\": \"xtls\",
                \"xtlsSettings\": {
                    \"serverName\": \"${web_domain}\", // 替换成你的真实域名
                    \"allowInsecure\": false // 禁止不安全证书
                }
            }
        },
        // 5.2 用freedom协议直连出站，即当routing中指定'direct'流出时，调用这个协议做处理
        {
            \"tag\": \"direct\",
            \"protocol\": \"freedom\"
        },
        // 5.3 用blackhole协议屏蔽流量，即当routing中指定'block'时，调用这个协议做处理
        {
            \"tag\": \"block\",
            \"protocol\": \"blackhole\"
        }
    ]
}" | sudo tee /usr/local/etc/xray/config.json
}

# 结束提示
end_tip() {
    success_msg "将xray配置信息写入 $HOME/xray_client.txt"
    echo -e "xray客户端\n
配置文件：/usr/local/etc/xray/config.json
日志文件：/var/log/xray/access.log、/var/log/xray/error.log
服务开关方式：systemctl start/stop xray
查看客户端xray监听的端口：配置文件的/inbounds节点，默认sock5为10800，http为10801" >"$HOME/xray_client.txt"
}

main() {
    check_env
    install_xray
    get_info
    config_xray
    end_tip
    systemctl restart xray
    success_msg '脚本执行完成'
}

main

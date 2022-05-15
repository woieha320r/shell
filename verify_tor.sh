#!/bin/sh
#
# 验证tor连接状态
#   依赖proxychains
#

set -e

curl_res=''
if curl_res=$(proxychains curl https://check.torproject.org/) && [ "$(printf '%s' "${curl_res}" | grep -c 'This browser is configured to use Tor')" != '0' ]; then
    printf '连接Tor网络成功：%s\n' "$(printf '%s' "${curl_res}" | grep 'Your IP address appears to be')"
else
    exit 1
fi

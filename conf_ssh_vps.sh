#!/bin/sh
#
# 配置ssh登录方式时的服务端脚本
#   用于被调用
# 测试环境：Debian 10.2
#

set -e

ssh_rsa_pub="${1}"
sshd_port="${2}"
ssher="${3}"
ssh_client_name="${4}"

printf "[节点] 删除服务器关于本机的公钥条目\n"
sed -i "/ ${ssh_client_name}/d" /root/.ssh/authorized_keys 2>/dev/null || true
printf "[节点] 上传公钥并修改权限\n"
mkdir -p /root/.ssh 2>/dev/null || true
printf "%s" "${ssh_rsa_pub}" >>/root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

printf "[节点] 配置sshd开启密钥登录并关闭密码登录\n"
printf "sshd_config路径 (默认/etc/ssh/sshd_config): "
read -r _sshd_config
_sshd_config="${_sshd_config:-/etc/ssh/sshd_config}"
# shellcheck disable=SC2015
[ ! -f "${_sshd_config}" ] && printf "[错误] %s不存在" "${_sshd_config}" || true
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' "${_sshd_config}" 2>/dev/null || true
sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' "${_sshd_config}" 2>/dev/null || true
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' "${_sshd_config}" 2>/dev/null || true

printf "[节点] 关闭root登录\n"
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' "${_sshd_config}" 2>/dev/null || true

printf "[节点] 修改sshd端口\n"
sed -i "s/Port 22/Port ${sshd_port}/g" "${_sshd_config}" 2>/dev/null || true

printf "[节点] 新建用户\n"
if ! id -u "${ssher}" >/dev/null 2>&1; then
    adduser --ingroup root --shell /bin/bash --home "/home/${ssher}" "${ssher}"
    _ssher_home="/home/${ssher}"
else
    printf "%s的家目录 (默认/home/%s): " "${ssher}" "${ssher}"
    read -r _ssher_home
fi
_ssher_home="${_ssher_home:-/home/${ssher}}"
printf "将 %s ALL=(ALL:ALL) ALL 写到 root ALL=(ALL:ALL) ALL 下面后保存退出编辑器\n[回车开始]: " "${ssher}"
read -r _any_press
visudo

printf "[节点] 将公钥追加至/home/%s/.ssh/authorized_keys并修改权限\n" "${ssher}"
mkdir -p "${_ssher_home}/.ssh" 2>/dev/null || true
grep "${ssh_client_name}" /root/.ssh/authorized_keys >>"${_ssher_home}/.ssh/authorized_keys"
chown -R "${ssher}" "${_ssher_home}"
chmod 700 "${_ssher_home}/.ssh"
chmod 600 "${_ssher_home}/.ssh/authorized_keys"

printf "[节点] 删掉root的公钥条目\n"
sed -i "/ ${ssh_client_name}/d" /root/.ssh/authorized_keys 2>&1 || true

printf "[节点] 重启sshd\n"
systemctl restart sshd

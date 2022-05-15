#!/bin/sh
#
# macOS端修改VPS的原始ssh登录方式：
#   使用密钥登录而非密码登录
#   建立新用户用于ssh登录而不是使用root
#   修改默认sshd端口
#   在macOS端生成用于ssh和scp的shell脚本
# 测试环境：macOS 12.6
#

set -e

# 引用函数
_sh_path="$(cd "$(dirname "${0}")" && pwd)"
# shellcheck disable=SC1091
. "${_sh_path}/function.sh"

# 检查运行环境
check_env() {
    if ! command -v ssh >/dev/null 2>&1; then error_msg '执行端ssh不存在'; fi
    if ! command -v sed >/dev/null 2>&1; then error_msg '执行端sed不存在'; fi
    warn_msg '确保执行端sed为GNU版'
    warn_msg '确保服务端存在adduser命令'
    warn_msg '确保ssh允许root通过密码登录'
    whether_exit
}

# 配置ssh客户端
config_ssh() {
    printf "ssh_config路径 (默认/etc/ssh/ssh_config): "
    read -r _ssh_config
    _ssh_config="${_ssh_conifg:-/etc/ssh/ssh_config}"
    [ -f "${_ssh_config}" ] || error_msg "未找到${_ssh_config}"
    # 配置客户端定时心跳
    # shellcheck disable=SC2015
    [ "$(grep -c 'ServerAliveInterval' "${_ssh_config}")" = '0' ] && sudo sed -i '/^Host \*/a\    ServerAliveInterval 20' "${_ssh_config}" || true
    # shellcheck disable=SC2015
    [ "$(grep -c 'ServerAliveCountMax' "${_ssh_config}")" = '0' ] && sudo sed -i '/^Host \*/a\    ServerAliveCountMax 999' "${_ssh_config}" || true
}

# 生成密钥
generate_keygen() {
    printf "服务器公网IP："
    read -r sshd_ip
    ssh_rsa_file="${HOME}/.ssh/${sshd_ip}"
    ssh_rsa_pub_file="${ssh_rsa_file}.pub"
    /bin/rm -rf "${ssh_rsa_file}" 2>/dev/null || true
    sed -i "/^${sshd_ip}/d" "${HOME}/.ssh/known_hosts" 2>/dev/null || true
    mkdir -p "${HOME}/.ssh" 2>/dev/null || true
    ssh-keygen -t rsa -b 2048 -P "" -f "${ssh_rsa_file}" >/dev/null
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${ssh_rsa_file}"
}

# 配置sshd服务端
config_sshd() {
    _ssh_rsa_pub="$(cat "${ssh_rsa_pub_file}")"
    /bin/rm -rf "${ssh_rsa_pub_file}"
    _ssh_client_name=$(printf "%s" "${_ssh_rsa_pub}" | tr ' ' "\n" | tail -n 1)
    printf '用于替代tcp:22的ssh登录端口: '
    read -r sshd_port
    ssher=''
    while [ "${ssher}" = 'root' ] || [ -z "${ssher}" ]; do
        printf '用于ssh登录的root组用户名 (不可是root或空，不存在将通过adduser新建)：'
        read -r ssher
    done
    # 在服务器端执行指令
    printf "接下来需要输入服务器root密码\n"
    enter_to_continue
    [ -f "${_sh_path}/conf_ssh_vps.sh" ] || error_msg "找不到${_sh_path}/conf_ssh_vps.sh"
    # 下边的重定向，用vscode保存会把重定向挪到行尾，不知道为啥🤷‍♂️。而且这种方式不能交互式，只能先把脚本传到远程再执行了
    # ssh -o StrictHostKeyChecking=no -tt "root@${sshd_ip}" '/bin/sh -s' < "${_sh_path}/conf_ssh_vps.sh" "${_ssh_rsa_pub}" "${sshd_port}" "${ssher}" "${_ssh_client_name}"
    scp -o StrictHostKeyChecking=no "${_sh_path}/conf_ssh_vps.sh" "root@${sshd_ip}:~"
    ssh -o StrictHostKeyChecking=no -t "root@${sshd_ip}" "sh ~/conf_ssh_vps.sh \"${_ssh_rsa_pub}\" \"${sshd_port}\" \"${ssher}\" \"${_ssh_client_name}\"; rm ~/conf_ssh_vps.sh;"
}

# 生成ssh连接信息
generate_ssh_sh() {
    printf "#!/bin/sh

# 用于以%s身份ssh连接%s
ssh -i %s/.ssh/%s -p %s %s@%s

# root密码: 待记录
# %s密码: 待记录
" "${ssher}" "${sshd_ip}" "${HOME}" "${sshd_ip}" "${sshd_port}" "${ssher}" "${sshd_ip}" "${ssher}" >"${HOME}/ssh_${sshd_ip}.sh"

    chmod 700 "${HOME}/ssh_${sshd_ip}.sh"
}

# 生成scp连接信息
generate_scp_sh() {
    printf "#!/bin/sh
#
# 用于以%s身份scp上传文件至%s
#

set -e

# shellcheck disable=SC2015
[ \${#} -lt 2 ] && printf \"[错误] 参数个数必须>2，最后一个是服务端路径\\\n\" && false

_index=1
_command_scp='scp -P ${sshd_port} -i ${ssh_rsa_file}'
for _param in \"\${@}\"; do
    [ \${_index} -eq \${#} ] && _command_scp=\"\${_command_scp} ${ssher}@${sshd_ip}:\${_param}\" || _command_scp=\"\${_command_scp} \${_param}\"
    _index=\$((_index + 1))
done

eval \"\${_command_scp}\"
" >"${HOME}/scp_${sshd_ip}.sh"

    chmod 700 "${HOME}/scp_${sshd_ip}.sh"
}

main() {
    require_macOS
    check_env
    node_msg '配置客户端ssh'
    config_ssh
    node_msg '生成ssh密钥'
    generate_keygen
    node_msg '配置ssh服务端'
    config_sshd
    node_msg "在${HOME}/ssh_${sshd_ip}.sh处生成使用ssh以${ssher}身份登录${sshd_ip}的脚本"
    generate_ssh_sh
    node_msg "在${HOME}/scp_${sshd_ip}.sh处生成使用scp以${ssher}身份上传文件至${sshd_ip}的脚本"
    generate_scp_sh
    success_msg '执行完成，已可禁用vps的22端口'
}

main

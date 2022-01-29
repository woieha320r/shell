#!/bin/bash

#*******************************************************************************
# macOS端修改VPS的原始ssh登录方式：
#   使用密钥登录而非密码登录
#   建立新用户用于ssh登录而不是使用root
#   修改默认sshd端口
#
# Warn:
#   脚本需要的工具均为GNU，脚本不负责安装
#   脚本会修改客户机的/etc/ssh/ssh_config、$HOME/.ssh/{${IP}, known_hosts}
#   脚本会修改服务机的/etc/ssh/sshd_config、新用户家目录/.ssh/authorized_keys
#
# 完成日期：2022/09/12
#*******************************************************************************

# 全局变量
sh_path=""
sshd_ip=""
ssh_rsa_file=""
ssh_rsa_pub_file=""

# 引用函数
sh_path="$(dirname "$0")"
# shellcheck disable=SC1091
source "${sh_path}/function.sh" 2>/dev/null || {
    echo '需将function.sh放到脚本同级目录'
    exit 1
}

# 检查环境
check_env() {
    node_msg '检查执行环境'
    check_os 'macOS 12.5.1'
    if ! which brew >/dev/null 2>&1; then
        error_msg 'brew不可用'
    fi
    if ! brew_install_app gnu-sed openssh; then
        error_msg '软件安装失败'
        exit 1
    fi
    if [ ! -f /usr/local/etc/ssh/ssh_config ] || [ "$(grep -c 'ssh_config' /usr/local/etc/ssh/ssh_config)" == '0' ]; then
        error_msg '未在/usr/local/etc/ssh/ssh_config检测到ssh配置文件'
        exit 1
    fi
}

# 获取信息
get_info() {
    node_msg '获取执行信息'
    read -rp '新建用于ssh登录的用户名：' ssher
    echo "${ssher}将被置入root组、以/home/${ssher}为家目录、以/bin/bash为默认shell"
    whether_exit
    read -rp '用于替代TCP:22的ssh登录端口：' sshd_port
    read -rp '服务器公网IP：' sshd_ip
    ssh_rsa_file="$HOME/.ssh/${sshd_ip}"
    ssh_rsa_pub_file="${ssh_rsa_file}.pub"
}

# 配置ssh客户端
config_ssh() {
    node_msg '配置ssh客户端'
    if [ "$(grep -c 'ServerAliveInterval' /usr/local/etc/ssh/ssh_config)" == '0' ]; then
        sudo sed -i '/^Host \*/a\    ServerAliveInterval 20' /usr/local/etc/ssh/ssh_config
    fi
    if [ "$(grep -c 'ServerAliveCountMax' /usr/local/etc/ssh/ssh_config)" == '0' ]; then
        sudo sed -i '/^Host \*/a\    ServerAliveCountMax 999' /usr/local/etc/ssh/ssh_config
    fi
}

# 生成密钥
generate_keygen() {
    node_msg '生成ssh密钥'
    # 删除已有同IP的私钥
    [ -f "${ssh_rsa_file}" ] && /bin/rm -rf "${ssh_rsa_file}"
    # 从已知主机文件中删掉此IP条目
    [ -f "$HOME/.ssh/known_hosts" ] && sed -i "/^${sshd_ip}/d" "$HOME/.ssh/known_hosts"
    # 创建此IP的公私钥并修改访问权限
    [ ! -d "$HOME/.ssh" ] && mkdir "$HOME/.ssh"
    ssh-keygen -t rsa -b 2048 -P "" -f "${ssh_rsa_file}"
    chmod 700 "$HOME/.ssh"
    chmod 600 "${ssh_rsa_file}"
}

# 配置sshd服务端
config_sshd() {
    node_msg '配置sshd服务端'
    # 为执行服务器指令记录公钥信息并删掉本地公钥文件
    local ssh_rsa_pub
    ssh_rsa_pub=$(cat "${ssh_rsa_pub_file}")
    /bin/rm -rf "${ssh_rsa_pub_file}"
    ssh_client_name=$(echo -e "${ssh_rsa_pub}" | tr ' ' "\n" | tail -n 1)
    # 在服务器端执行指令
    echo "输入服务器root密码回车登录"
    ssh -o StrictHostKeyChecking=no -t root@"${sshd_ip}" "
        echo '删掉服务器关于本机的公钥条目';
        sed -i '/ ${ssh_client_name}/d' /root/.ssh/authorized_keys 2>/dev/null;
        echo '将新公钥上传至服务器并修改权限';
        [ ! -d /root/.ssh ] && mkdir /root/.ssh;
        echo -e '${ssh_rsa_pub}' >> /root/.ssh/authorized_keys;
        chmod 700 /root/.ssh;
        chmod 600 /root/.ssh/authorized_keys;
        echo '配置sshd开启密钥登录并关闭密码登录';
        sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config;
        sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config;
        sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config;
        echo '关闭root登录';
        sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/ssh_config;
        echo '修改sshd端口';
        sed -i 's/Port 22/Port ${sshd_port}/g' /etc/ssh/sshd_config;
        echo '新建用户${ssher}';
        if id -u ${ssher}; then
            echo '${ssher}用户已存在';
        else
            echo '新建${ssher}';
            adduser --ingroup root --shell /bin/bash --home /home/${ssher} ${ssher};
        fi;
        echo -n '将 ${ssher} ALL=(ALL:ALL) ALL 写到 root ALL=(ALL:ALL) ALL 下面后保存退出编辑器';
        read -rp '[回车开始]: ' any_press;
        visudo;
        echo '将刚刚的公钥追加 至 /home/${ssher}/.ssh/authorized_keys 并修改权限';
        [ ! -d /home/${ssher}/.ssh ] && mkdir /home/${ssher}/.ssh;
        grep '${ssh_client_name}' /root/.ssh/authorized_keys >> /home/${ssher}/.ssh/authorized_keys;
        chown -R ${ssher} /home/${ssher}/.ssh
        chmod 700 /home/${ssher}/.ssh
        chmod 600 /home/${ssher}/.ssh/authorized_keys;
        echo '删掉root的公钥条目';
        sed -i '/ ${ssh_client_name}/d' /root/.ssh/authorized_keys;
        echo '重启sshd'
        systemctl enable sshd;
        systemctl restart sshd;
    "
}

# 生成ssh连接信息
generate_ssh_sh() {
    node_msg '生成ssh连接脚本'
    echo -e "#!/bin/bash

# 用于以${ssher}身份ssh连接${sshd_ip}
ssh -i $HOME/.ssh/${sshd_ip} -p ${sshd_port} ${ssher}@${sshd_ip}

# root密码: 未记录
# ${ssher}密码: 未记录

# scp命令: scp -P ${sshd_port} -i ${ssh_rsa_file} 源路径 目标路径 (远程主机路径表示为: ${ssher}@${sshd_ip}:远程主机路径(当前目录为${ssher}加目录))
" >"$HOME/ssh_${sshd_ip}.sh"

    chmod 700 "$HOME/ssh_${sshd_ip}.sh"
    success_msg "用于ssh连接的${sshd_ip}脚本已生成：$HOME/ssh_${sshd_ip}.sh\n已可禁用服务器22端口"
}

main() {
    check_env
    get_info
    config_ssh
    generate_keygen
    config_sshd
    generate_ssh_sh
    success_msg '脚本执行完成'
}

main

#!/bin/bash

###############################################################################
# 描述    公共函数，只做被引用使用
# 用法    在需要使用的sh文件中，在调用之前 "source 本文件路径"
# 修改    2022/10/13
###############################################################################

# 全局变量
any_str=""
install_app_err=""

# 执行节点提示
node_msg() {
    echo -e "\033[34m[节点]\033[0m $1"
    return 0
}

# 成功提示
success_msg() {
    echo -e "\033[32m[成功]\033[0m $1"
    return 0
}

# 警告提示
warn_msg() {
    echo -e "\033[33m[警告]\033[0m $1"
    return 0
}

# 错误提示
error_msg() {
    echo -e "\033[31m[错误]\033[0m $1"
    return 0
}

# 是否中断执行
whether_exit() {
    any_str=""
    until [ "${any_str}" == 'y' ] || [ "${any_str}" == 'n' ]; do
        echo ''
        read -rp '是否继续执行[y/n]:' any_str
    done
    [ "${any_str}" == 'n' ] && exit 0 || return 0
}

# 回车继续
enter_to_continue() {
    echo ''
    read -rp '[回车继续]' any_str
    return 0
}

# 检查系统版本
check_os() {
    local os_ver
    if os_ver="$(sw_vers 2>/dev/null)"; then
        # 去除字符串前后空格: str | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g'
        os_ver="macOS $(echo -e "${os_ver}" | grep 'ProductVersion' | cut -f2 -d: | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g')"
    elif [ -f /etc/issue ]; then
        os_ver="$(cut -f1 -d \\ </etc/issue | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g')"
    else
        os_ver='未知'
    fi
    warn_msg "脚本编写环境为[$1]，当前执行环境为[${os_ver}]"
    whether_exit
}

# 为brew安装的软件设置PATH。以用原名使用GNU软件而非带着g或gnu-前缀，且比自带的优先
# 若要使用自带的，需使用绝对路径或卸载brew安装的或在.bashrc中删掉对应条目并source重加载
brew_app_path() {
    local app_brew_prefix
    # shellcheck disable=SC1091
    source "$HOME/.bashrc" >/dev/null 2>&1
    if app_brew_prefix=$(brew --prefix "$1" 2>/dev/null) && [ "$(echo "$PATH" | grep -c "$1")" == '0' ]; then
        echo "export PATH=\"${app_brew_prefix}/libexec/gnubin:\$PATH\"" >>"$HOME/.bashrc"
    fi
}

# 通过Homebrew安装软件
brew_install_app() {
    install_app_err=""
    local app=""
    for app in "$@"; do
        if ! brew list "${app}" >/dev/null 2>&1 && ! brew install "${app}" >/dev/null 2>&1; then
            install_app_err="${install_app_err} ${app}"
        else
            brew_app_path "${app}"
            success_msg "${app} 安装完成"
        fi
    done
    [ -n "${install_app_err}" ] && error_msg "如下软件安装失败\n${install_app_err}" && return 1
    return 0
}

# 通过apt-get安装软件
apt_install_app() {
    install_app_err=""
    local app=""
    if ! sudo apt update; then
        error_msg 'apt 更新失败'
        exit 1
    fi
    for app in "$@"; do
        if [ "$(apt-cache search "${app}" | grep -c \'^"${app}"\$\')" == '0' ] && ! sudo apt install "${app}" -y; then
            install_app_err="${install_app_err} ${app}"
        else
            success_msg "${app} 安装完成"
        fi
    done
    [ -n "${install_app_err}" ] && error_msg "如下软件安装失败\n${install_app_err}" && return 1
    return 0
}

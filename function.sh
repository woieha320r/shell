#!/bin/sh
#
# 公共函数
#

# shell前背景色定义
# 打印黑字：printf "${_BLACKl}黑字${_NORMAL}"
# 打印黑底白字：printf "[40;37m黑底白字${_NORMAL}"
_NORMAL="[0m"
# 黑背景：49
_BLACK="[30m"
# 红背景：41
_RED="[31m"
# 绿背景：42
_GREEN="[32m"
# 黄背景：43
_YELLOW="[33m"
# 蓝背景：44
_BLUE="[34m"
# 紫背景：45
_PURPLE="[35m"
# 青背景：46
_CYAN="[36m"
# 白背景：47
_WHITE="[37m"

node_msg() {
    printf "${_BLUE}[节点]${_NORMAL} %s\n" "$1"
    return 0
}

success_msg() {
    printf "${_GREEN}[成功]${_NORMAL} %s\n" "$1"
    return 0
}

warn_msg() {
    printf "${_YELLOW}[警告]${_NORMAL} %s\n" "$1"
    return 0
}

error_msg() {
    printf "${_RED}[错误]${_NORMAL} %s\n" "$1" >&2
    return 1
}

upper_case() {
    tr '[:lower:]' '[:upper:]'
}

lower_case() {
    tr '[:upper:]' '[:lower:]'
}

starts_with() {
    echo "${1}" | grep -- "^${2}" >/dev/null 2>&1
}

ends_with() {
    echo "${1}" | grep -- "${2}\$" >/dev/null 2>&1
}

contains() {
    echo "${1}" | grep -- "${2}" >/dev/null 2>&1
}

require_not_sudo() {
    #don't check if it's not in an interactive shell
    [ -t 1 ] || return 0
    if [ "$SUDO_GID" ] && [ "$SUDO_COMMAND" ] && [ "$SUDO_USER" ] && [ "$SUDO_UID" ]; then
        if [ "$SUDO_USER" = "root" ] && [ "$SUDO_UID" = "0" ]; then
            #it's root using sudo, no matter it's using sudo or not, just fine
            return 0
        fi
        if [ -n "$SUDO_COMMAND" ]; then
            #it's a normal user doing "sudo su", or `sudo -i` or `sudo -s`, or `sudo su acmeuser1`
            ends_with "$SUDO_COMMAND" /bin/su || contains "$SUDO_COMMAND" "/bin/su " || grep "^$SUDO_COMMAND\$" /etc/shells >/dev/null 2>&1
            return $?
        fi
        #otherwise
        return 1
    fi
    return 0
}

require_macOS() {
    [ "$(uname)" != 'Darwin' ] && error_msg '要求运行于macOS'
    return 0
}

require_Linux() {
    [ "$(uname)" != 'Linux' ] && error_msg '要求运行于Linux'
    return 0
}

whether_exit() {
    _any_str=""
    until [ "${_any_str}" = 'y' ] || [ "${_any_str}" = 'n' ]; do
        printf "\n是否继续执行 [y/n]: "
        read -r _any_str
    done
    [ "${_any_str}" = 'n' ] && return 1
    return 0
}

enter_to_continue() {
    _any_str=""
    printf "\n回车继续 [enter]: "
    read -r _any_str
    return 0
}

# 为brew安装的软件设置PATH。以用原名使用GNU软件而非带着g或gnu-前缀，且比自带的优先
# 若要使用自带的，需使用绝对路径或卸载brew安装的或在.profile中删掉对应条目并重加载
brew_app_path() {
    # shellcheck disable=SC1091
    . "${HOME}/.profile" >/dev/null 2>&1 || true
    if _app_brew_prefix=$(brew --prefix "${1}" 2>/dev/null) && [ "$(printf "%s" "${PATH}" | grep -c "${1}")" = '0' ]; then
        printf "export PATH=\"%s/libexec/gnubin:\${PATH}\"\n" "${_app_brew_prefix}" >>"${HOME}/.profile"
    fi
    return 0
}

# 通过包管理器安装软件，brew安装前需初始化$PATH
install_app_by_pkg_manage() {
    # 判定并更新包管理器
    _pkg_manage=""
    if command -v brew >/dev/null 2>&1 && _pkg_manage='brew' && brew update; then
        true
    elif command -v apt-get >/dev/null 2>&1 && _pkg_manage='apt-get' && sudo apt-get update; then
        true
    elif [ -z "${_pkg_manage}" ]; then
        error_msg '识别包管理器（仅支持brew、apt）'
    else
        error_msg "更新${_pkg_manage}源"
    fi
    # 安装软件
    _install_app_err=""
    for _app in "$@"; do
        if [ "${_pkg_manage}" = 'brew' ] && brew install "${_app}" >/dev/null && brew_app_path "${_app}"; then
            success_msg "安装${_app}"
        elif [ "${_pkg_manage}" = 'apt-get' ] && sudo apt-get install "${_app}" -y >/dev/null; then
            success_msg "安装${_app}"
        else
            _install_app_err="${_install_app_err} ${_app}"
        fi
    done
    # 失败软件提示
    [ -n "${_install_app_err}" ] && error_msg "安装失败：${_install_app_err}"
    return 0
}

# 备份
bak() {
    for _file in "${@}"; do
        _bak_dir="$(dirname "${_file}")/bak"
        [ ! -d "${_bak_dir}" ] && mkdir -p "${_bak_dir}"
        mv -f "${_file}" "${_bak_dir}/$(basename "${_file}").bak.$(/bin/date +'%Y%m%d%H%M%S')"
    done
    return 0
}

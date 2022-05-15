#!/bin/sh
#
# zsh、bash公用配置文件
#

# shell前背景色定义
# 打印黑字：printf "${_BLACKl}黑字${_NORMAL}"
# 打印黑底白字：printf "[40;37m黑底白字${_NORMAL}"
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
# 重置
_NORMAL="[0m"

# 使用mv替代rm
TRASH="${HOME}"/.Trash
if [ ! -d "${TRASH}" ]; then
    mkdir "${TRASH}"
fi
trash() {
    mv "$@" "${TRASH}"
}
alias rm=trash

# 常用别名
alias ls='ls --color=always'
alias ll='ls -lhA --time-style=long-iso'
alias cp='cp -i'
alias mv='mv -i'
# alias rm="echo Don\'t use this command"
alias date="date +'%Y/%m/%d-%H:%M:%S'"

# 配置不同shell的特征，不按指定语法配置颜色会因为计算命令长度错误而出现字符残留，常现于tab补全或上下查看历史记录时
case "${0}" in
*zsh)
    PS1="
┌──(%F{cyan}%n%f@%F{red}%M%f %D{%Y/%m/%d-%H:%M:%S}) [%F{yellow}%d%f]
└─%F{green}%#%f "
    ;;
*bash)
    PS1="
┌──(\\[${_CYAN}\\]\u\\[${_NORMAL}\\]@\\[${_RED}\\]\H\\[${_NORMAL}\\] \D{%Y/%m/%d-%H:%M:%S}) [\\[${_YELLOW}\\]\w\\[${_NORMAL}\\]]
└─\\[${_GREEN}\\]\$\\[${_NORMAL}\\] "
    ;;
esac
#

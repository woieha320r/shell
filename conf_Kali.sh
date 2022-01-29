#!/bin/bash

#*******************************************************************************
# 对新安装的Kali，自动化自定义流程：
#   修改本地语言环境
#   安装Android-Studio
#
# 完成日期：2022/10/13
#*******************************************************************************

# 全局变量
sh_path=""
need_reboot=""

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
    sudo apt update && sudo apt upgrade -y
}

# 配置中文环境
conf_zh_CH() {
    node_msg '配置中文环境'
    [ "$LANG" == 'zh_CN.UTF-8' ] || {
        warn_msg '使用空格选中/取消；取消en_US.UTF-8 UTF-8；选中zh_CN.UTF-8 UTF-8；OK后选择zh_CN.UTF-8 UTF-8为默认环境'
        enter_to_continue
        sudo dpkg-reconfigure locales
    }
    # 中文man、中文输入法
    if ! apt_install_app manpages-zh fcitx fcitx-pinyin; then
        error_msg '软件安装失败'
        exit 1
    fi
    warn_msg '在输入法配置面板中选择auto，重启后使用ctrl+space切换中英文输入法'
    enter_to_continue
    need_reboot="true"
}

# 安装Android-Studio
install_android_studio() {
    node_msg '安装Android-Studio'
    local pkg_address
    warn_msg '在如下网址下载linux.tar.gz包，记录下载后的文件地址\nhttps://developer.android.google.cn/studio?hl=zh-cn#downloads'
    echo ''
    read -rp '安装包绝对路径:' pkg_address
    if ! sudo tar -zxvf "${pkg_address}" -C /usr/local/; then
        error_msg 'android-studio安装包解压失败'
        exit 1
    fi
    sudo rm "${pkg_address}"
    if ! apt_install_app lib32z1 lib32ncurses6 libbz2-1.0 mesa-utils lib64stdc++6-i386-cross; then
        error_msg '软件安装失败'
        exit 1
    fi
    # 桌面快捷方式
    echo -e "[Desktop Entry]\nName = AndroidStudio\ncomment = android studio\nExec = /usr/local/android-studio/bin/studio.sh\nIcon = /usr/local/android-studio/bin/studio.png\nTerminal = false\nType = Application" | sudo tee /usr/share/applications/jetbrains-studio.desktop
}

main() {
    check_env
    conf_zh_CH
    # install_android_studio
    [ "${need_reboot}" == 'true' ] && warn_msg '需重启系统'
    success_msg '脚本执行完成'
}

main

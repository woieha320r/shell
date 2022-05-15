#!/bin/sh
#
# 配置Kali
#   修改本地语言环境
#   # 安装Android-Studio
# 测试环境：Kali 2022.3
#
# 如果apt慢，就换国内源，注释官源并添加如下中科大源至/etc/apt/sources.list
# deb http://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib
# deb-src http://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib
# 如果无法访问github等，就加代理：export http_proxy=ip:port; export https_proxy=ip:port; 或=socks5://ip:port
#

# 引用函数
_sh_path="$(cd "$(dirname "${0}")" && pwd)"
# shellcheck disable=SC1091
. "${_sh_path}/function.sh"

# 切换国内源
change_kali_source() {
    printf '是否切换软件源 [y/others]: '
    read -r _any_str
    if [ "${_any_str}" = 'y' ]; then
        [ -f /etc/apt/sources.list ] || sudo /etc/apt/sources.list /etc/apt/sources.list.bak
        sudo cp "${_sh_path}/source_Kali.txt" /etc/apt/sources.list
        sudo apt update
    fi
    printf '是否升级 [y/others]: '
    read -r _any_str
    [ "${_any_str}" = 'n' ] || sudo apt upgrade -y
}

# 配置中文环境
conf_zh_CH() {
    [ "${LANG}" = 'zh_CN.UTF-8' ] || {
        printf "使用空格选中/取消；\n取消en_US.UTF-8 UTF-8；\n选中zh_CN.UTF-8 UTF-8；\nOK后选择zh_CN.UTF-8 UTF-8为默认环境\n"
        enter_to_continue
        sudo dpkg-reconfigure locales
    }
    # 中文man、中文输入法
    install_app_by_pkg_manage manpages-zh fcitx fcitx-pinyin
    printf "设置切换输入法的快捷键：输入法配置(Fcitx Configuration) -> 全局配置(Global Config) -> 快捷键(Hot Key) -> 切换激活/非激活输入法(Trigger Input Method)\n"
    enter_to_continue
    need_reboot="true"
}

# 安装Android-Studio
install_android_studio() {
    printf "在如下网址下载linux.tar.gz包，记录下载后的文件地址\nhttps://developer.android.google.cn/studio?hl=zh-cn#downloads\n"
    enter_to_continue
    printf "安装包绝对路径: "
    read -r pkg_address
    mkdir -p /usr/local 2>/dev/null || true
    sudo tar -zxvf "${pkg_address}" -C /usr/local/
    sudo /bin/rm -rf "${pkg_address}"
    install_app_by_pkg_manage lib32z1 lib32ncurses6 libbz2-1.0 mesa-utils lib64stdc++6-i386-cross
    # 桌面快捷方式
    printf "%s\n" '[Desktop Entry]' \
        'Name = AndroidStudio' \
        'comment = android studio' \
        'Exec = /usr/local/android-studio/bin/studio.sh' \
        'Icon = /usr/local/android-studio/bin/studio.png' \
        'Terminal = false' \
        'Type = Application" | sudo tee /usr/share/applications/jetbrains-studio.desktop'
}

main() {
    require_Linux
    node_msg '切换软件源'
    change_kali_source
    node_msg '配置中文环境'
    conf_zh_CH
    # node_msg '安装Android Studio'
    # install_android_studio
    # shellcheck disable=SC2015
    [ "${need_reboot}" = 'true' ] && warn_msg '需重启系统' || true
    success_msg '执行完成'
}

main

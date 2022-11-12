#!/bin/sh
#
# 配置macOS
#   sh、brew、常用软件
# 测试环境：macOS 12.6
#

set -e

# 引用函数
_sh_path="$(cd "$(dirname "${0}")" && pwd)"
# shellcheck disable=SC1091
. "${_sh_path}/function.sh"

# 日常配置
conf_normal() {
    # 允许任何来源
    sudo spctl --master-disable
    # Finder显示隐藏文件
    defaults write com.apple.finder AppleShowAllFiles -boolean true
    # 不显示隐藏文件：defaults write com.apple.finder AppleShowAllFiles -boolean false; killall Finder
    killall Finder
    bak "${HOME}/iCloud"
    ln -s "${HOME}/Library/Mobile Documents/com~apple~CloudDocs" "${HOME}/iCloud"
    return 0
}

# sh配置
conf_sh() {
    # 生成~/.profile
    bak "${HOME}/.profile"
    cat "${_sh_path}/profile_init.sh" >"${HOME}/.profile"
    chmod u+x "${HOME}/.profile"
    # 将~/.profile软链为各shell配置文件
    set -- "${HOME}/.zprofile" "${HOME}/.bash_profile" "${HOME}/.zshrc" "${HOME}/.bashrc"
    bak "${@}"
    for profile in "${@}"; do
        ln -s "${HOME}/.profile" "${profile}"
    done
}

# vim配置
conf_vim() {
    # 生成 ~/.vimrc
    bak "${HOME}/.vimrc" "${HOME}/.vim/colors/monokai.vim"
    /bin/cp -f "${_sh_path}/vimrc" "${HOME}/.vimrc"
    # 软链 ~/.vim/colors/monokai.vim
    _vim_colors_dir="${HOME}/.vim/colors"
    mkdir -p "${_vim_colors_dir}" 2>/dev/null || true
    /bin/cp -f "${_sh_path}/monokai.vim" "${_vim_colors_dir}/monokai.vim"
}

# 安装brew
install_brew() {
    if ! command -v brew >/dev/null 2>&1; then
        xcode-select --install
        warn_msg "请在Command Line Tools For Xcode安装完成后继续\n（如果失败需进入 https://developer.apple.com/download/more/ 搜索下载安装包）"
        enter_to_continue

        # 卸载：/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/HomebrewUninstall.sh)"
        /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)" || error_msg '安装brew'
        # 中科大安装方式：http://mirrors.ustc.edu.cn/help/brew.git.html

        # 将Home-brew程序所有权设为当前用户（之前的brew安装脚本有此问题导致警告）
        sudo chown -R "$(whoami)" /usr/local/Homebrew/Library/Taps/homebrew || warn_msg '设置homebrew所有权'
    fi
    brew update >/dev/null || error_msg '更新brew源'
    return 0
}

# 配置Android studio
conf_androidstudio() {
    # 将adb、emulator配入环境变量
    [ "$(grep -c "${HOME}/Library/Android/sdk/platform-tools ${HOME}/.profile")" != '0' ] || printf "export PATH=\"%s/Library/Android/sdk/platform-tools:\${PATH}\"\n" "${HOME}" >>"${HOME}/.profile"
    [ "$(grep -c "${HOME}/Library/Android/sdk/emulator ${HOME}/.profile")" != '0' ] || printf "export PATH=\"%s/Library/Android/sdk/emulator:\${PATH}\"\n" "${HOME}" >>"${HOME}/.profile"
    return 0
}

# 配置git
conf_git() {
    git_name="$(git config --get user.name)"
    git_email="$(git config --get user.email)"
    printf "当前git：提交名[%s]，提交邮箱[%s]\n是否修改 [y/others]: " "${git_name}" "${git_email}"
    read -r press_key
    [ "${press_key}" != 'y' ] && return 0
    printf "git提交名："
    read -r git_name
    printf "git提交邮箱："
    read -r git_email
    git config --global user.name "${git_name}"
    git config --global user.email "${git_email}"
    return 0
}

# 配置jdk
conf_jdk() {
    [ -d '/Library/Java/JavaVirtualMachines' ] || sudo mkdir -p /Library/Java/JavaVirtualMachines
    sudo ln -sfn /usr/local/opt/openjdk@8/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-8.jdk
    # shellcheck disable=SC2016
    [ "$(grep -c '/usr/local/opt/openjdk@8/bin:' "$HOME/.profile")" != '0' ] || echo 'export PATH="/usr/local/opt/openjdk@8/bin:${PATH}"' >>"$HOME/.profile"
    return 0
}

# 配置maven
conf_maven() {
    [ -d "$HOME/.m2" ] || mkdir "$HOME/.m2"
    [ -f "$HOME/.m2/settings.xml" ] || cp /usr/local/Cellar/maven/3.8.6/libexec/conf/settings.xml "$HOME/.m2/"
}

# 安装软件
install_app() {
    install_app_by_pkg_manage coreutils \
        gnu-sed \
        gawk \
        grep \
        wget \
        ffmpeg \
        openjdk@8 \
        maven \
        the-unarchiver \
        stretchly \
        vmware-fusion \
        wechat \
        baidunetdisk \
        visual-studio-code \
        homebrew/cask/docker \
        wpsoffice-cn \
        thunder \
        vlc \
        google-chrome \
        cheatsheet
    # android-studio

    # conf_androidstudio
    conf_jdk
    conf_maven

    #  解决macOS的vscode中vim模式无法连按
    defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
    defaults write com.jetbrains.intellij ApplePressAndHoldEnabled -bool false
}

# 其他操作，备忘
other_operation() {
    # iCloud云的本地文件都在 ${HOME}/Library/Mobile\ Documents 下

    # 禁止深度睡眠
    sudo pmset -a hibernatemode 0 standby 0 autopoweroff 0

    # 刷新DNS
    # 断网然后执行，执行后开网，最好再清下浏览器缓存和历史记录
    sudo killall -HUP mDNSResponder

    # 用xattr删掉扩展属性（当提示app损坏或无法修改音乐标签时）
    # https://blog.csdn.net/lovechris00/article/details/113060237

    # 自定义启动台行数
    defaults write com.apple.dock springboard-rows -int 自定义数或Default
    # 自定义启动台列数
    defaults write com.apple.dock springboard-columns -int 自定义数或Default
    # 重启启动台
    killall Dock

    # 修改mac地址：重启会恢复
    new_addr=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
    sudo /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -z
    sudo ifconfig "网卡名称(en0/en1...)" ether "${new_addr}"
    networksetup -detectnewhardware
}

# 入口函数
main() {
    require_macOS
    node_msg '日常配置'
    conf_normal
    node_msg 'sh配置'
    conf_sh
    node_msg 'vim配置'
    conf_vim
    node_msg 'git配置'
    conf_git
    node_msg '安装brew'
    install_brew
    node_msg '安装软件'
    # 重置$PATH，脚本中使用brew安装软件时依赖原始PATH值
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    install_app
    warn_msg '去AppStore下载adguard fro safari'
    success_msg '执行完成'
}

main

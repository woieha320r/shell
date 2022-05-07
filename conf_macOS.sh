#!/bin/bash

#*******************************************************************************
# 对新安装的macOS，自动化自定义流程：
#   使用在国内环境安装Home-brew的开源脚本
#   使用Home-brew安装常用的GNU软件；设置原名使用且优先于系统自带的同名命令
#   配置vim
#
# Warn：
#   脚本会修改.bashrc；如果其他命令的结果和环境变量相关，那么调用命令前先source .bashrc
#   脚本配置的.bash_profile仅用于加载.bashrc
#
# 完成日期：2022/09/11
#*******************************************************************************

# 全局变量
sh_path=""

# 引用函数
sh_path="$(dirname "$0")"
# shellcheck disable=SC1091
source "${sh_path}/function.sh" 2>/dev/null || {
    echo '需将function.sh放到脚本同级目录'
    exit 1
}

# 配置bash配置文件
bash_conf() {
    [ ! -f "$HOME/.bashrc" ] && touch "$HOME/.bashrc"
    # 将自己的macOS_bashrc文件导入$HOME/.bashrc
    if [ "$(grep -c '# macOS_bashrc' "$HOME/.bashrc")" == '0' ] && [ -f "${sh_path}/bashrc" ]; then
        cat "${sh_path}/bashrc" >>"$HOME/.bashrc"
    fi
    [ ! -f "$HOME/.bash_profile" ] && touch "$HOME/.bash_profile"
    # bash为默认终端的macos进入Terminal不读取.bashrc读取.bash_profile不知道为啥🤷‍♂️
    if [ "$(grep -c "source $HOME/.bashrc" "$HOME/.bash_profile")" == '0' ]; then
        echo "source $HOME/.bashrc" >>"$HOME/.bash_profile"
    fi
}

# 修改用户默认shell为bash
change_shell_bash() {
    node_msg '检查bash配置文件'
    local new_bash_path
    # brew安装后，which会返回brew安装的，不知道为啥
    # shellcheck disable=SC1091
    source "$HOME/.bashrc" 2>/dev/null
    if ! new_bash_path="$(which bash 2>/dev/null)"; then
        warn_msg '暂无bash程序'
        return 0
    fi
    bash_conf
    [ "$SHELL" == "${new_bash_path}" ] && return 0
    node_msg "将用户默认shell修改为 ${new_bash_path}"
    if [ "$(grep -c "${new_bash_path}" /etc/shells)" == '0' ]; then
        warn_msg "需要手动将 ${new_bash_path} 加入文件末尾"
        enter_to_continue
        sudo vim /etc/shells
    fi
    if [ "$(grep -c "${new_bash_path}" /etc/shells)" == '0' ]; then
        node_msg "已放弃将用户默认shell修改为 ${new_bash_path}"
    # TODO: 会出现密码输错的情况，可以改成循环直到成功
    elif ! chsh -s "${new_bash_path}"; then
        error_msg '修改用户默认shell失败'
    fi
    return 0
}

# 自定义vim
conf_vim() {
    if [ ! -d "$HOME/.vimrc" ] && [ ! -f "$HOME/.vimrc" ] && [ ! -L "$HOME/.vimrc" ] && [ -f "${sh_path}/vimrc" ]; then
        ln -s "${sh_path}/vimrc" "$HOME/.vimrc"
    fi
    if [ ! -d "$HOME/.vim/colors/monokai.vim" ] && [ ! -f "$HOME/.vim/colors/monokai.vim" ] && [ ! -L "$HOME/.vim/colors/monokai.vim" ] && [ -f "${sh_path}/monokai.vim" ]; then
        mkdir -p "$HOME/.vim/colors/" && ln -s "${sh_path}/monokai.vim" "$HOME/.vim/colors/monokai.vim"
    fi
}

# 与brew无关的
noneed_brew() {
    change_shell_bash
    conf_vim

    node_msg "软链iCloud文件夹 -> $HOME/iCloud"
    [ ! -f "$HOME/iCloud" ] && [ ! -d "$HOME/iCloud" ] && [ ! -L "$HOME/iCloud" ] && ln -s "$HOME/Library/Mobile\ Documents/com~apple~CloudDocs" "$HOME/iCloud"
    # iCloud云的本地文件都在 $HOME/Library/Mobile\ Documents 下

    node_msg '设置为允许任何来源的app'
    sudo spctl --master-disable

    node_msg '在Finder中显示隐藏文件'
    defaults write com.apple.finder AppleShowAllFiles -boolean true
    killall Finder
    # 不显示隐藏文件：defaults write com.apple.finder AppleShowAllFiles -boolean false; killall Finder

    return 0
}

# 安装brew
install_brew() {
    node_msg '安装Command Line Tools For Xcode'
    xcode-select --install
    warn_msg "请在Command Line Tools For Xcode安装完成后继续
    （如果失败可进入 https://developer.apple.com/download/more/ 搜索下载安装包）"
    enter_to_continue

    node_msg '安装Home-Brew'
    # 卸载：/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/HomebrewUninstall.sh)"
    if ! /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"; then
        # 中科大安装方式：http://mirrors.ustc.edu.cn/help/brew.git.html
        error_msg 'Home-brew安装失败'
        exit 1
    fi

    node_msg '将Home-brew程序所有权设为当前用户（之前的brew安装脚本有此问题导致警告'
    sudo chown -R "$(whoami)" /usr/local/Homebrew/Library/Taps/homebrew

    if ! brew update; then
        error_msg 'brew更新失败'
        exit 1
    fi
}

# 安装软件
install_app() {
    node_msg '安装软件'
    brew_install_app coreutils \
        binutils \
        diffutils \
        findutils \
        gnutls \
        gnu-tar \
        gnu-sed \
        gnu-getopt \
        gnu-time \
        gnu-which \
        gawk \
        grep \
        gzip \
        screen \
        wget \
        git \
        openssh \
        the-unarchiver \
        stretchly \
        ffmpeg \
        vmware-fusion \
        wechat \
        baidunetdisk \
        intellij-idea-ce \
        visual-studio-code \
        homebrew/cask/docker \
        wpsoffice-cn \
        bash \
        thunder \
        vlc \
        google-chrome \
        android-studio

    change_shell_bash

    # 将adb、emulator配入环境变量
    [ "$(grep -c "$HOME/Library/Android/sdk/platform-tools" <"$HOME/.bashrc")" == '0' ] && echo "export PATH=\"$HOME/Library/Android/sdk/platform-tools:\$PATH\"" >>"$HOME/.bashrc"
    [ "$(grep -c "$HOME/Library/Android/sdk/emulator" <"$HOME/.bashrc")" == '0' ] && echo "export PATH=\"$HOME/Library/Android/sdk/emulator:\$PATH\"" >>"$HOME/.bashrc"
}

# 配置git
config_git() {
    node_msg '配置git全局信息'
    local git_name
    local git_email
    local press_key
    git_name="$(git config --get user.name)"
    git_email="$(git config --get user.email)"
    warn_msg "当前git：提交名[${git_name}]，提交邮箱[${git_email}]"
    read -rp '是否修改[y/others]:' press_key
    [ "${press_key}" != 'y' ] && return 0
    read -rp 'git提交名：' git_name
    read -rp 'git提交邮箱：' git_email
    git config --global user.name "${git_name}"
    git config --global user.email "${git_email}"
}

# 运行结束提示
end_tip() {
    warn_msg "装软件前先看有没有gnu的，一般g或gnu-开头，如果以后也需要就加到脚本里"
}

# 入口函数
main() {
    check_os 'macOS 12.5.1'
    noneed_brew
    # shellcheck disable=SC1091
    source "$HOME/.bashrc" 2>/dev/null
    if ! which brew >/dev/null 2>&1; then
        install_brew
    fi
    install_app
    config_git
    end_tip
    success_msg '脚本执行完成'
}

main

# 其他操作，备忘作用
other_operation() {
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
    local new_addr
    new_addr=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
    sudo /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -z
    sudo ifconfig "网卡名称(en0/en1...)" ether "${new_addr}"
    networksetup -detectnewhardware
}


# macOS_bashrc
PS1='\n┌──(\[\e[36m\]\u\[\e[0m\]@\[\e[31m\]\h\[\e[0m\] \D{%Y/%m/%d} \t)-[\[\e[33m\]\W\[\e[0m\]]\n└─\[\e[32m\]\$\[\e[0m\] '
alias ls='ls --color=auto'
alias ll='ls -lhA --time-style=long-iso'
alias cp='cp -i'
alias mv='mv -i'
# alias rm="echo Don\'t use this command"
alias date="date +'%Y-%m-%d %H:%M:%S'"

# Java
# export JAVA_HOME=/usr/local/java
# export PATH=${PATH}:${JAVA_HOME}/bin
# 1.5之后不再需要classpath
# export CLASSPATH=.:${CLASSPATH}:${JAVA_HOME}/lib/dt.jar:${JAVA_HOME}/lib/tools.jar

trash() {
    TRASH="$HOME/.Trash"
    [ ! -d "${TRASH}" ] && mkdir "${TRASH}"                                         
    mv "$@" "${TRASH}"
}
alias rm=trash

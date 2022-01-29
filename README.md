# shell
```text
系统配置脚本（macOS、Debian...
``` 

### macOS自定义配置
```text
脚本：conf_macOS.sh
要求：
    macOS端执行；
    执行者有权使用sudo；
    需要如下文件位于同级目录：fuction.sh、monokai.vim、vimrc、bashrc；
```

### macOS端修改服务器22端口的ssh为禁用root的公私钥登录
```text
脚本：change_ssh_auth_macOS.sh
要求：
    macOS端执行；
    root可以以ssh方式通过22端口登录服务端；
    服务端已放行用以替代22的新端口；
```

### 配置服务端xray（Debian）
```text
用以自动化 https://xtls.github.io/document/level-0 的流程
脚本：xray_server_debian.sh
要求：
    Debian端root执行；
    服务端已放行80、443端口；
    拥有一个无CDN的，可解析至服务器IP的域名；
```

### 配置客户端xray（macOS）
```text
脚本：xray_client_macOS.sh
要求：
    macOS端执行；
    服务端xray可用；
    HomeBrew可用；
```

### 配置客户端xray（Kali）
```text
脚本：xray_client_kali.sh
要求：
    Kali端执行；
    服务端xray可用；
    apt-get可用；
```

### 配置kali端tor
```text
脚本：tor_Kali.sh
要求：
    xray可用；
    apt-get可用；
```
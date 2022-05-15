# shell
```text
自用配置脚本（macOS、Debian...
同时注释也作为一些操作的备忘
``` 

### macOS自定义配置
```text
脚本：conf_macOS.sh
说明：允许任何来源、隐藏文件...profile、vim、homebrew、常用软件...
```

### macOS端修改服务器22端口的ssh为禁用root的公私钥登录
```text
脚本：conf_ssh_macOS.sh
说明：修改服务端sshd，密钥登录、换端口、禁root
```

### 配置代理（服务端）
```text
脚本：proxy_server.sh
说明：
    使用xray软件搭配xtls协议
    用以自动化 https://xtls.github.io/document/level-0 的流程
要求：
    Debian端root执行；
    服务端已放行80、443端口；
    拥有一个无CDN的，可解析至服务器IP的域名；
```

### 配置代理（macOS端）
```text
脚本：proxy_macOS.sh
说明：在macOS上配置xray客户端，配置proxychains来让命令行工具也可使用代理
要求：HomeBrew可用；
```

### 配置代理（Kali端）
```text
脚本：proxy_Kali.sh
说明：在Kali端配置xray客户端、tor。配置proxychains来让命令行工具使用tor
```

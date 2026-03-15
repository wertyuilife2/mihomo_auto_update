## 起因
想在服务器上装梯子，调研了半天没发现合适的方案满足自己的需求：
1. 需要是headless mihomo for linux。
2. 支持自动更新订阅，且是热更新，不能导致断网。不是proxy_provider，而是自动更新整个mihomo的config.yaml（和GUI比如Clash Verge类似）。
3. 支持web ui，这样我好手动调整节点；且在自动更新订阅后不会扰乱web ui的config，因为有可能热更后的web ui config不够安全。
4. 不要systemd，要自己手动开关mihomo，就和windows的clash verge使用体验类似。

## 方案
1. 启动mihomo，使用cli的参数覆盖web ui的地址设置，实测这样不会被后续的config更改覆盖。
2. 启动一个auto update脚本，定时地使用mihomo的/configs api进行热更新，更新之前会检查下载的config合法性。实测这样不会造成断连（当然要网络设置变动不大）。
3. 二者相互不依赖，任意一个在任意时间挂掉也不影响任何事，比较鲁棒。

## 使用
### 安装mihomo
1. 官网下载安装版例如`.deb`，然后`sudo apt install ./xx.deb`。不需要启动mihomo的`systemd`服务，我不希望用它。

2. 保证脚本运行环境中有`python`，然后`pip install pyyaml`。

### 开启代理
执行`./start.sh`启动mihomo以及自动更新订阅的脚本。如果任意一个已经启动了则会跳过，如果启动失败了则会报错。

相关参数现在统一放在`config.conf`里，只要改这一份文件就行。格式就是简单的`KEY=VALUE`，不需要改 shell 脚本。

`auto_update.sh`和`update_subs.sh`放在`tools/`目录里，由`start.sh`统一拉起。运行日志会写到`logs/mihomo.log`和`logs/auto_update.log`。

如果脚本目录下存在`config_override.yaml`，那么每次自动更新时会先把它merge到从订阅源下载的`config.yaml.new`，再用 mihomo 校验合并后的结果，最后才执行`PUT /configs`热更新。这个merge步骤现在由python脚本完成，所以需要环境里有装有`pyyaml`包的`python`。

覆盖规则是：

1. 同名的标量值会被覆盖，例如`mixed-port`。
2. 同名的对象会会被覆盖，例如`tun`、`dns`；如果想改成递归合并模型，可以自行解除merge_yaml.py中merge()方法的注释。
3. 顶层的`rules`会做拼接，`config_override.yaml`里的规则会放在前面。
4. 除了`rules`之外，其他数组会整体替换，不做按元素merge。

例如：

```yaml
mixed-port: 7893
dns:
  enable: true
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-redirect: true
```

如果手动修改mihomo的`config.yaml`，改动会被auto update脚本的热更覆盖掉。所以推荐通过脚本目录下的`config_override.yaml`保留本地改动，适合放 TUN、DNS、rules等你不希望被订阅覆盖的配置。

### 关闭代理
方法一（推荐）：直接在web UI里切换成直连。web UI地址默认为`127.0.0.1:9090`。为了安全不对外开放，只能通过ssh tunnel访问。

方法二：执行`./kill.sh`，这会同时杀掉mihomo和auto update脚本。注意，因为一般来说代理要配合修改`~/.bashrc`：

``` bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
```

直接杀掉mihomo可能会导致http和https不可用。

### 查看代理情况
用`ps -ef | grep mihomo` 和 `ps -ef | grep auto_update`匹配进程字符串查找。

## 启用TUN Mode
TUN mode能通过设置虚拟网卡，直接作用在网络层而非应用层。可以让系统的所有网络流量自动进入代理，而不需要应用自己设置代理（eg. export http_proxy），能满足一些需要强行代理的特殊需求（比如用梯子完成chatgpt Oauth）。

开启TUN后需要注意3点：

1. 开启TUN后，DNS也会走mihomo代理，所以在mihomo的config.yaml中必须设置`dns: true`。

2. 在linux上，要同时开启`auto-route: true`和`auto-redirect: true`，不然有很多流量不会被mihimo透明代理，比如curl。

3. dns设置的`nameserver`不要随便填，如果你的proxies本身也是用这个解析的话，就会出现奇怪的回环问题。

    默认的一个国内dns一个google dns已经很稳了，mihomo会并发查询选更快的：

    ``` 
    nameserver: # 默认
    - 114.114.114.114
    - 8.8.8.8
    ```

所以，推荐的tun配置是：
```
dns:
  enable: true

tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-redirect: true
```

以上配置以尽量简化为目标，其实还有一些配置可能需要自行调整，例如`tun.auto-detect-interface`、`dns.enhanced-mode`、`tun.stack`。

### Tips

一般来说，trojan代理没法转发ICMP协议，所以即使mihomo在TUN mode下可以代理ICMP协议，也没法真正通过trojan代理出站，而是会自动选择为DIRECT。这个选择会无视任何rules的匹配。

然而，如果你设置`dns.enhanced-mode`为`fake-ip`，而不是默认的`redir-host`时，mihomo会做出fake ping echo，从而给你一种你能ping通外网的假象（通常延迟非常低，<1ms）。不要被这个现象所干扰。


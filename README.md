## TD;LR
方便地在headless linux上使用mihomo，并自动更新订阅。

## 起因
想在服务器上装梯子，调研了半天没发现合适的方案满足自己的需求：
1. 需要是headless mihomo for linux。
2. 支持自动更新订阅，且是热更新，不能导致断网。不是proxy_provider，而是自动更新整个mihomo的config.yaml（和GUI比如Clash Verge类似）。
3. 支持web UI，这样我好手动调整节点；且在自动更新订阅后不会扰乱web UI的config，因为有可能热更后的web UI config不够安全。
4. 不要systemd，要自己手动开关mihomo，就和windows的clash verge使用体验类似。
5. 如果服务器不能访问互联网/梯子节点，能方便地使用本地/局域网的代理服务+TUN mode来处理服务器上的所有流量。
6. 不需要额外依赖，能简单地应用在各种vanilla headless linux服务器上。

## 方案
1. 启动mihomo，使用cli的参数覆盖web UI的地址设置，实测这样不会被后续的config更改覆盖。
2. 启动一个auto update脚本，定时地使用mihomo的`/configs` api进行热更新，更新之前会检查下载的`config.yaml`的合法性。实测这样不会造成断连（当然要网络设置变动不大）。
3. 二者相互不依赖，任意一个在任意时间挂掉也不影响任何事，比较鲁棒。
4. 如果服务器不能访问互联网/梯子节点，则让服务器临时使用局域网代理/SSH反向代理。

## 使用
### 安装mihomo

```
cd tools/mihomo_files
sudo apt install ./mihomo-linux-amd64-v3-v1.19.21.deb # 你也可以自己下载最新版mihomo
pip install pyyaml # 保证脚本运行环境中有python以及pyyaml
```

不需要启动mihomo的`systemd`服务，我不希望用它。

### 开启代理

1. 首先，在`config/config.conf`的`SUB_URL`项填写你的订阅地址。
2. 如果你的服务器不能访问互联网/无法连接到你的梯子节点，直接去[服务器没有网络](#服务器没有网络)。
3. 执行`./start.sh`，启动自动更新订阅脚本和mihomo。
4. 访问`http://127.0.0.1:9090/ui`，通过web UI查看mihomo状态，配置代理节点。
5. （可选）配置`config/config_override.yaml`，每次自动更新订阅时，它会被merge到订阅配置文件中。适合放 TUN、DNS、rules等你不希望被订阅覆盖的配置。

**merge规则**（可在`tools/merge_yaml.py`中修改）：

1. 同名的标量值会被覆盖，例如`mixed-port`。
2. 同名的对象会会被覆盖，例如`tun`、`dns`；如果想改成递归合并模型，可以自行解除`merge_yaml.py`中`merge()`方法的注释。
3. 顶层的`rules`会做拼接，`config/config_override.yaml`里的规则会放在前面。
4. 除了`rules`之外，其他数组会整体替换，不做按元素merge。

不要手动修改mihomo的`config.yaml`，会被auto update脚本的热更覆盖掉。

### 关闭代理
方法一（推荐）：直接在web UI里切换成直连。web UI地址默认为`127.0.0.1:9090`。为了安全不对外开放，只能通过ssh tunnel访问。

方法二：执行`./kill.sh`，这会杀掉mihomo和auto update脚本，并取消 logrotate 注册。注意，因为一般来说代理要配合修改`~/.bashrc`，例如：

``` bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
```

直接杀掉mihomo可能会导致http和https不可用。

### 查看代理进程情况
用`ps -ef | grep mihomo` 和 `ps -ef | grep auto_update`匹配进程字符串查找。

## 启用TUN Mode
TUN mode能通过设置虚拟网卡，直接作用在网络层而非应用层。可以让系统的所有网络流量自动进入代理，而不需要应用自己设置代理（eg. export http_proxy），能满足一些需要强行代理的特殊需求（比如用梯子完成chatgpt Oauth）。

默认的`config/config_override.yaml`不开启TUN mode，解除注释即可开启TUN mode，TUN mode下不要配置`http_proxy`/`https_proxy`环境变量，以免循环代理。

开启TUN后需要注意3点：
1. 开启TUN后，DNS请求大概率也会走mihomo代理，所以在mihomo的config.yaml中必须设置`dns: true`，打开mihomo的DNS解析逻辑。
2. 在linux上，要同时开启`auto-route: true`和`auto-redirect: true`，不然有很多流量不会被mihimo透明代理，比如curl。
3. dns设置的`nameserver`不要随便填，如果你的proxies本身也是用这个解析的话，就会出现奇怪的回环问题。

    默认的一个国内dns一个google dns已经很稳了，mihomo会并发查询选更快的：

    ``` 
    nameserver: # 默认
    - 114.114.114.114
    - 8.8.8.8
    ```

## Tips

### 服务器没有网络

如果你的服务器根本没有网络，或者是你的服务器无法连接到你的梯子节点，但你还想用TUN mode+局域网的代理服务来代理流量，那么推荐的做法是使用`./start_offline.sh`：

1. 配置`config/config_offline.yaml`中的`mylocalproxy`的`port`，与你配置的局域网代理服务端口一致。
2. 启动`./start_offline.sh`，这会让TUN mode的所有流量直接走你的局域网代理。

如果没有局域网代理服务，可以用你本机+SSH反向代理的方式来实现，例如在你的ssh config中设置`RemoteForward 7897 127.0.0.1:7897`。

### 下载geo数据库或UI时卡住

如果mihomo在下载geo database时卡住，可以把`tools/mihomo_files/geoip.metadb`直接拷贝到`~/.config/mihomo`。

同理，如果mihomo在下载ui前端时卡住，可以把`tools/mihomo_files/ui`文件夹直接拷贝到`~/.config/mihomo`。

### ICMP转发与dns fake-ip

Trojan协议没法转发ICMP协议，所以即使mihomo在TUN mode下可以代理ICMP协议，也没法真正通过trojan代理出站，而是会自动选择为DIRECT。这个选择会无视任何rules的匹配。

然而，如果你设置`dns.enhanced-mode`为`fake-ip`，而不是默认的`redir-host`时，mihomo会做出fake ping echo，从而给你一种你能ping通外网的假象（通常延迟非常低，<1ms）。不要被这个现象所干扰。

## 我还是不懂

首先在 `config/config.conf` 的 `SUB_URL` 中填入你的订阅地址。

### 1. 如果服务器能够访问到梯子节点

#### 1.1 你想普通地代理 http/https
- 在 `config/config_override.yaml` 里注释 `dns` 和 `tun` 部分
- 在 `~/.bashrc` 里添加 `export http_proxy= ...`和`export https_proxy= ...`
- 使用 `./start.sh`

#### 1.2 你想用 TUN 模式代理所有流量
- 在 `config/config_override.yaml` 里使用 `dns` 和 `tun` 部分
- 使用 `./start.sh`

---

### 2. 如果服务器访问不到梯子节点（没网，或者网络环境不好）

#### 2.1 你想普通地代理 http/https
- 配置 SSH 反向代理 / 局域网代理服务
- 在 `~/.bashrc` 里添加 `export http_proxy= ...`和`export https_proxy= ...`

#### 2.2 你想用 TUN 模式代理所有流量
- 配置 SSH 反向代理 / 局域网代理服务
- 设置 `config/config_offline.yaml` 中 `mylocalproxy` 的 `server` 和 `port` 分别为代理服务的地址和端口
- 使用 `./start_offline.sh`

---

通过`http://127.0.0.1:9090`访问mihomo的web UI，进行手动调整和查看状态。

使用TUN mode时，不要在 `~/.bashrc` 里配置 http 代理的环境变量，以避免循环代理。

## Troubleshooting

- 似乎在TUN模式下直接kill -9 mihomo进程会导致一些问题，比如变成僵尸进程之类的，可能需要ip link delete Meta 2>/dev/null。在kill之后删除虚拟网卡。

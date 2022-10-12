#### 1.3 操作系统初始化配置（新增node 上执行）
```bash
# 关闭防火墙
 
# 关闭selinux
sed -i 's/enforcing/disabled/' /etc/selinux/config  # 永久
setenforce 0  # 临时

# 关闭firewalld
systemctl stop firewalld.service
systemctl disable firewalld.service

# 关闭swap
swapoff -a  # 临时
sed -ri 's/.*swap.*/#&/' /etc/fstab    # 永久

# 根据规划设置主机名
hostnamectl set-hostname <hostname>

# 在master添加hosts
cat >> /etc/hosts << EOF
192.168.31.61 k8s-master1
192.168.31.62 k8s-node1
192.168.31.63 k8s-node2
EOF


# 1.安装ipset和ipvsadm
yum install ipset ipvsadm -y
# 2.添加需要加载的模块写入脚本文件
cat <<EOF> /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
# 3.为脚本添加执行权限
chmod +x /etc/sysconfig/modules/ipvs.modules
# 4.执行脚本文件
/bin/bash /etc/sysconfig/modules/ipvs.modules
# 5.查看对应的模块是否加载成功
lsmod | grep -e ip_vs -e nf_conntrack_ipv4

#修改 linux 的内核参数，添加网桥过滤和地址转发功能
cat <<EOF> /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

#重新加载配置
sysctl -p

#加载网桥过滤模块
modprobe br_netfilter

#查看网桥过滤模块是否加载成功，如果有则加载成功
lsmod |grep br_netfilter




# 时间同步
yum install ntpdate -y
ntpdate time.windows.com

```
### 2. 安装Docker/kubeadm/kubelet【新增node 上执行】
这里使用Docker作为容器引擎，也可以换成别的，例如containerd
#### 2.1 安装Docker
```bash
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install docker-ce
systemctl enable docker && systemctl start docker
```

配置镜像下载加速器：
```bash
cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl restart docker
docker info
```
#### 2.2 添加阿里云YUM软件源
```bash
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```
#### 2.3 安装kubeadm，kubelet和kubectl
由于版本更新频繁，这里指定版本号部署：
```bash
yum install -y kubelet-1.20.0 kubeadm-1.20.0 kubectl-1.20.0

systemctl enable kubelet
```

### 生成扩容 node 节点命令 (master执行)
由于默认token 有效期为24小时，当过期之后，该token 就不可用了。这时就需要在master 重新创建token，可以直接使用命令快捷生成：
```bash
kubeadm token create --print-join-command
```
> 如果你用的是蓝鲸脚本部署的 k8s 请使用蓝鲸的命令进行扩容
> curl -fsSL https://bkopen-1252002024.file.myqcloud.com/ce7/bcs.sh | bash -s -- -i k8sctrl

### 在中控机配置 ssh 免密登录
本文中会提供命令片段方便您部署。部分命令片段会从中控机上调用 `ssh` 在 k8s node 上执行远程命令，所以需提前配置免密登录。

在 **中控机** 执行如下命令：
``` bash
k8s_nodes_ips=$(kubectl get nodes -o jsonpath='{$.items[*].status.addresses[?(@.type=="InternalIP")].address}')
test -f /root/.ssh/id_rsa || ssh-keygen -N '' -t rsa -f /root/.ssh/id_rsa  # 如果不存在rsa key则创建一个。
# 开始给发现的ip添加ssh key，期间需要您输入各节点的密码。
for ip in $k8s_nodes_ips; do
  ssh-copy-id "$ip" || { echo "failed on $ip."; break; }  # 如果执行失败，则退出
done
```
常见报错：
1. `Host key verification failed.`，且开头提示 `REMOTE HOST IDENTIFICATION HAS CHANGED`: 检查目的主机是否重装过。如果确认没连错机器，可以参考提示（如 `Offending 类型 key in /root/.ssh/known_hosts:行号`）删除 `known_hosts` 文件里的对应行。


### 安装默认的storageClass，采取local pv provisioner的charts安装。由于bcs.sh脚本默认安装的环境以及自动做好了 /mnt/blueking 目录的挂载。直接用默认参数安装localpv即可。

#### 新增 node节点执行
```bash
cat <<EOF >> /etc/fstab
/data/bcs/localpv/vol01 /mnt/blueking/vol01 none defaults,bind 0 0
/data/bcs/localpv/vol02 /mnt/blueking/vol02 none defaults,bind 0 0
/data/bcs/localpv/vol03 /mnt/blueking/vol03 none defaults,bind 0 0
/data/bcs/localpv/vol04 /mnt/blueking/vol04 none defaults,bind 0 0
/data/bcs/localpv/vol05 /mnt/blueking/vol05 none defaults,bind 0 0
/data/bcs/localpv/vol06 /mnt/blueking/vol06 none defaults,bind 0 0
/data/bcs/localpv/vol07 /mnt/blueking/vol07 none defaults,bind 0 0
/data/bcs/localpv/vol08 /mnt/blueking/vol08 none defaults,bind 0 0
/data/bcs/localpv/vol09 /mnt/blueking/vol09 none defaults,bind 0 0
/data/bcs/localpv/vol10 /mnt/blueking/vol10 none defaults,bind 0 0
/data/bcs/localpv/vol11 /mnt/blueking/vol11 none defaults,bind 0 0
/data/bcs/localpv/vol12 /mnt/blueking/vol12 none defaults,bind 0 0
/data/bcs/localpv/vol13 /mnt/blueking/vol13 none defaults,bind 0 0
/data/bcs/localpv/vol14 /mnt/blueking/vol14 none defaults,bind 0 0
/data/bcs/localpv/vol15 /mnt/blueking/vol15 none defaults,bind 0 0
/data/bcs/localpv/vol16 /mnt/blueking/vol16 none defaults,bind 0 0
/data/bcs/localpv/vol17 /mnt/blueking/vol17 none defaults,bind 0 0
/data/bcs/localpv/vol18 /mnt/blueking/vol18 none defaults,bind 0 0
/data/bcs/localpv/vol19 /mnt/blueking/vol19 none defaults,bind 0 0
/data/bcs/localpv/vol20 /mnt/blueking/vol20 none defaults,bind 0 0
EOF

for i in $(grep 'mnt' /etc/fstab |awk '{print $1}'); do mkdir -p $i; done
for i in $(grep 'mnt' /etc/fstab |awk '{print $2}'); do mkdir -p $i; done
mount -a
```
#### master上执行
```bash
helmfile -f 00-localpv.yaml.gotmpl sync
kubectl get pv -A   #看一下是不是已经创建了PV。
```
挂载后记得看下对应/mnt/blueking下有没有生成对应的目录。


### 部署基础套餐后台（master执行）
执行部署基础套餐命令（该步骤根据机器环境配置，大概需要 8 ~ 16 分钟）
```bash
helmfile -f base.yaml.gotmpl sync
```
此时可以新开一个终端下，执行如下命令观察 pod 状态变化：
```bash
kubectl get pods -n blueking -w
```

### 配置 k8s node 的 DNS
k8s node 需要能从 bkrepo 中拉取镜像。因此需要配置 DNS 。

>**注意**
>
>pod 删除重建后，clusterIP 会变动，需刷新 hosts 文件。

请在 **中控机** 执行如下脚本 **生成 hosts 内容**，然后将其追加到所有的 `node` 的 `/etc/hosts` 文件结尾（如 pod 经历删除重建，则需要更新 hosts 文件覆盖 pod 相应的域名）。

``` bash
BK_DOMAIN=bkce7.bktencent.com  # 请和 domain.bkDomain 保持一致.
IP1=$(kubectl -n blueking get svc -l app.kubernetes.io/instance=ingress-nginx -o jsonpath='{.items[0].spec.clusterIP}')
IP2=$(kubectl -n blueking get svc -l app=bk-ingress-nginx -o jsonpath='{.items[0].spec.clusterIP}')
cat <<EOF
$IP1 $BK_DOMAIN
$IP1 bkrepo.$BK_DOMAIN
$IP1 docker.$BK_DOMAIN
$IP2 apps.$BK_DOMAIN
EOF
```

<a id="hosts-in-bk-ctrl" name="hosts-in-bk-ctrl"></a>

### 配置 docker 使用 http 访问 registry
在 SaaS 专用 node （如未配置专用 node，则为全部 node ）上执行命令生成新的配置文件：
``` bash
BK_DOMAIN="bkce7.bktencent.com"  # 请按需修改
cat /etc/docker/daemon.json | jq '.["insecure-registries"]+=["docker.'$BK_DOMAIN'"]'
```

检查内容无误后，即可将上述内容写入此 node 上的 `/etc/docker/daemon.json`。如果这些 node 的配置文件相同，您可以在中控机生成新文件后批量替换。

然后 reload docker 服务使之生效：
``` bash
systemctl reload docker
```

检查确认已经生效：
``` bash
docker info
```

预期可看到新添加的 `docker.$BK_DOMAIN` ，如果没有，请检查 docker 服务是否成功 reload：
``` yaml
 Insecure Registries:
  docker.bkce7.bktencent.com
  127.0.0.0/8
```


### 1、前置知识点
#### 1.1 生产环境可部署Kubernetes集群的两种方式
目前生产部署Kubernetes集群主要有两种方式：
-	kubeadm
Kubeadm是一个K8s部署工具，提供kubeadm init和kubeadm join，用于快速部署Kubernetes集群。
-	二进制包
从github下载发行版的二进制包，手动部署每个组件，组成Kubernetes集群。
这里采用kubeadm搭建集群。
kubeadm工具功能：
-	kubeadm init：初始化一个Master节点
-	kubeadm join：将工作节点加入集群
-	kubeadm upgrade：升级K8s版本
-	kubeadm token：管理 kubeadm join 使用的令牌
-	kubeadm reset：清空 kubeadm init 或者 kubeadm join 对主机所做的任何更改
-	kubeadm version：打印 kubeadm 版本
-	kubeadm alpha：预览可用的新功能
#### 1.2 准备环境
服务器要求：
-	建议最小硬件配置：2核CPU、2G内存、20G硬盘
-	服务器最好可以访问外网，会有从网上拉取镜像需求，如果服务器不能上网，需要提前下载对应镜像并导入节点

软件环境：
|软件|	版本|
|:---:|:----:|
|操作系统|	CentOS7.9_x64 （mini）|
Docker|	19-ce
Kubernetes|	1.20
服务器规划：|
角色|	IP
k8s-master|	192.168.31.61
k8s-node1|	192.168.31.62
k8s-node2|	192.168.31.63|

架构图：
 ![image](https://user-images.githubusercontent.com/66426170/166640545-9308c5b3-0af5-44ca-aba0-3047249fba96.png)

#### 1.3 操作系统初始化配置
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

#修改 linux 的内核参数，添加网桥过滤和地址转发功能
cat <<EOF> /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

#重新加载配置
sysctl --p

#加载网桥过滤模块
modprobe br_netfilter

# 3.为脚本添加执行权限
chmod +x /etc/sysconfig/modules/ipvs.modules
# 4.执行脚本文件
/bin/bash /etc/sysconfig/modules/ipvs.modules
# 5.查看对应的模块是否加载成功
lsmod | grep -e ip_vs -e nf_conntrack_ipv4


# 时间同步
yum install ntpdate -y
ntpdate time.windows.com

```
### 2. 安装Docker/kubeadm/kubelet【所有节点】
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
### 4. 部署Kubernetes Master
在192.168.31.61（Master）执行,

注意：别直接复制粘贴，要修改apiserver-advertise-address=${masterIP}
```bash
kubeadm init \
  --apiserver-advertise-address=192.168.31.61 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.20.0 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=all
  ```
-	--apiserver-advertise-address 集群通告地址
-	--image-repository 由于默认拉取镜像地址k8s.gcr.io国内无法访问，这里指定阿里云镜像仓库地址
-	--kubernetes-version K8s版本，与上面安装的一致
-	--service-cidr 集群内部虚拟网络，Pod统一访问入口
-	--pod-network-cidr Pod网络，，与下面部署的CNI网络组件yaml中保持一致
或者使用配置文件引导：
```bash
vi kubeadm.conf
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.20.0
imageRepository: registry.aliyuncs.com/google_containers 
networking:
  podSubnet: 10.244.0.0/16 
  serviceSubnet: 10.96.0.0/12 

kubeadm init --config kubeadm.conf --ignore-preflight-errors=all 
```
初始化完成后，最后会输出一个join命令，先记住，下面用。
拷贝kubectl使用的连接k8s认证文件到默认路径：
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
查看工作节点：
```bash
kubectl get nodes
NAME               STATUS     ROLES            AGE   VERSION
localhost.localdomain   NotReady   control-plane,master   20s   v1.20.0
```
注：由于网络插件还没有部署，还没有准备就绪 NotReady
参考资料：

https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-init/#config-file 

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node 
### 5. 加入Kubernetes Node
在192.168.31.62/63（Node）执行。
向集群添加新节点，执行在kubeadm init输出的kubeadm join命令：
```bash
kubeadm join 192.168.31.61:6443 --token 7gqt13.kncw9hg5085iwclx \
--discovery-token-ca-cert-hash sha256:66fbfcf18649a5841474c2dc4b9ff90c02fc05de0798ed690e1754437be35a01
```
如果添加节点时出现以下报错并卡住，请在master重新创建token，重新创建token的命令，请参考下一步
```bash
[root@localhost ~]# kubeadm join 192.168.31.61:6443 --token 7gqt13.kncw9hg5085iwclx \
> --discovery-token-ca-cert-hash sha256:66fbfcf18649a5841474c2dc4b9ff90c02fc05de0798ed690e1754437be35a01
[preflight] Running pre-flight checks
	[WARNING SystemVerification]: this Docker version is not on the list of validated versions: 20.10.15. Latest validated version: 19.03
 
```
默认token有效期为24小时，当过期之后，该token就不可用了。这时就需要重新创建token，可以直接使用命令快捷生成：
```bash
kubeadm token create --print-join-command
```
参考资料：https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
### 6. 安装网络插件，只在master节点操作即可 
下载YAML：
```bash
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
> 如果使用wget 下载不安全的https 报证书问题，可以执行这个命令解决。``
yum install -y ca-certificates
``


修改完后文件后，部署：
```bash
kubectl apply -f kube-flannel.yml
kubectl get pods -n kube-system
```
等 Pod都Running，节点也会准备就绪：
参考资料：

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
### 7. 测试kubernetes集群
在Kubernetes集群中创建一个pod，验证是否正常运行：
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pod,svc
```
访问地址：http://NodeIP:Port 
### 8. 部署 Dashboard （可选）
Dashboard是官方提供的一个UI，可用于基本管理K8s资源。
```bash
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml
```
课件中文件名是：kubernetes-dashboard.yaml
默认Dashboard只能集群内部访问，修改Service为NodePort类型，暴露到外部：
```bash
vi recommended.yaml
...
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30001
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort
...

kubectl apply -f recommended.yaml
kubectl get pods -n kubernetes-dashboard
```
访问地址：https://NodeIP:30001
创建service account并绑定默认cluster-admin管理员集群角色：
```bash
# 创建用户
kubectl create serviceaccount dashboard-admin -n kube-system
# 用户授权
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
# 获取用户Token
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
```
使用输出的token登录Dashboard。
 
 




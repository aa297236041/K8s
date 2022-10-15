```bash
#!/bin/bash
# 关闭selinux
set -e
sed -i 's/enforcing/disabled/' /etc/selinux/config  # 永久
setenforce 0  # 临时

# 关闭firewalld
systemctl stop firewalld.service
systemctl disable firewalld.service

# 关闭swap
swapoff -a  # 临时
sed -ri 's/.*swap.*/#&/' /etc/fstab    # 永久

# 根据规划设置主机名
read -p "请输入主机名：" hostname 

hostnamectl set-hostname $hostname

# 1.安装ipset和ipvsadm
yum install ipset ipvsadm -y
# 2.添加需要加载的模块写入脚本文件
cat <<EOF > /etc/sysconfig/modules/ipvs.modules
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
cat <<EOF > /etc/sysctl.d/kubernetes.conf
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

#配置 yum和epel 源
wget -O /etc/yum.repos.d/epel.repo http://mirrors.cloud.tencent.com/repo/epel-7.repo

cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum clean all
yum makecache


# 时间同步
yum install ntpdate -y
ntpdate time.windows.com

#安装Docker
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install docker-ce
systemctl enable docker && systemctl start docker

#配置镜像下载加速器
cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl restart docker
docker info

#安装kubeadm，kubelet和kubectl
yum install -y kubelet-1.20.0 kubeadm-1.20.0 kubectl-1.20.0

systemctl enable kubelet
```


### kube-proxy开启ipvs的前置条件
```bash
modprobe br_netfilter

cat > /etc/sysconfig/modules/ipvs.modules <<EOF 
#!/bin/bash
modprobe -- ip_vs 
modprobe -- ip_vs_rr 
modprobe -- ip_vs_wrr 
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4 
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```
### 安装 Docker 软件
```bash
yum install -y yum-utils device-mapper-persistent-data lvm2

yum-config-manager \
--add-repo \
http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum update -y && yum install -y docker-ce

# 创建 /etc/docker 目录
mkdir /etc/docker

# 配置 daemon.
cat > /etc/docker/daemon.json <<EOF 
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
 }
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

# 重启docker服务
systemctl daemon-reload && systemctl restart docker && systemctl enable docker
```
### 安装 Kubeadm （主从配置）
```bash
cat <<EOF > /etc/yum.repos.d/kubernetes.repo 
[kubernetes]
name=Kubernetes 
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64 enabled=1
gpgcheck=0 
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg 
http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg 
EOF

yum -y install kubeadm-1.15.1 kubectl-1.15.1 kubelet-1.15.1 
systemctl enable kubelet.service
```
### 初始化主节点
```bash
kubeadm config print init-defaults > kubeadm-config.yaml
localAPIEndpoint:
    advertiseAddress: 192.168.66.10 
kubernetesVersion: v1.15.1 
networking:
  podSubnet: "10.244.0.0/16" 
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1 
kind: KubeProxyConfiguration
featureGates:
  SupportIPVSProxyMode: true 
mode: ipvs

kubeadm init --config=kubeadm-config.yaml --experimental-upload-certs | tee kubeadm-init.log
```

### 加入主节点以及其余工作节点
```bash
执行安装日志中的加入命令即可
```
### 部署网络
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube- flannel.yml
```

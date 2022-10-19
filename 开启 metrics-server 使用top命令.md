版本列表 ：https://github.com/kubernetes-sigs/metrics-server/releases
```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.1/components.yaml
```

修改镜像仓库地址
vim components.yaml
```bash

  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        #新增这个配置，就不会去验证Kubelets提供的服务证书的CA。但是仅用于测试。 
        - --kubelet-insecure-tls
        # 替换为国内镜像
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.6.1
        imagePullPolicy: IfNotPresent
```

开始部署
```bash
kubectl apply -f components.yaml
```

检查示例配置
```bash
# 如果有问题，检查 metrics-server 是否正常启动
kubectl get --raw /apis/metrics.k8s.io/v1beta1  | jq
```

检查所以 node 占用性能情况
```bash
[root@master ~]# kubectl top nodes
NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
master   988m         12%    12447Mi         78%       
node01   1029m        12%    12246Mi         77%       
node02   1198m        14%    13303Mi         84%       
node03   763m         9%     9250Mi          58%       
node04   807m         10%    12075Mi         76%       
[root@master ~]# 
```
查看指定 node 占用性能情况
```bash
[root@master ~]# kubectl top nodes node01
NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
node01   1113m        13%    12264Mi         77%   
```

### 实验要求：
    - ingress 的域名统一为：www.testweb.com
    - 访问的页面内容统一为：Welcome: <自身的名字>
    - 暴露的端口必须为 8081，访问时为 www.testweb.com:8081
    
    
### 环境准备：
搭建 k8s 集群：可以参考 [k8s部署安装.md](https://github.com/aa297236041/K8s-/blob/main/k8s%E9%83%A8%E7%BD%B2%E5%AE%89%E8%A3%85.md)

<br/>

### k8s集群部署好后，开始实验
可以先拉取下面的镜像
```bash
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller:0.23.0
```

创建工作目录
```bash
mkdir /ingress
cd /ingress
```

下载 ingress-nginx 的 yaml 文件
```bash
wget https://github.com/aa297236041/K8s-/blob/main/ingress/mandatory.yaml
```

编辑 mandatory.yaml
```bash
vim mandatory.yaml
```
![image](https://user-images.githubusercontent.com/66426170/169336442-6ab0b905-42f7-463f-ab57-b25dc88966a8.png)



部署 Ingress-Nginx
```bash
kubectl apply -f mandatory.yaml

kubectl get pods --all-namespaces |grep ingress

kubectl get pods -n ingress-nginx -o wide
```

创建一个应用实例
```bash
cat >nginx-demo.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo
  namespace: default
spec:
  selector:
    app: nginx-demo
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx-demo
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF
```
```bash
kubectl apply -f nginx-demo.yaml

kubectl get pods
```

创建 ingress 规则, HTTP 配置 
```bash
cat >nginx-web-ingress.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-nginx-demo
  namespace: default
  annotations: 
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: www.testweb.com 
    http:
      paths:
      - path: /
        backend:
          serviceName: nginx-demo
          servicePort: 80
EOF
```
```bash
kubectl apply -f nginx-web-ingress.yaml

kubectl get ingress

```

### 如果要配置 HTTPS，看下面的配置
生成证书
```bash
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/local/bin/cfssl-certinfo

chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson /usr/local/bin/cfssl-certinfo

export PATH=/usr/local/bin:$PATH
```

定义一个 CA 机构
```bash
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF
```
```bash
cat > ca-csr.json <<EOF
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "CD",
            "ST": "CD"
        }
    ]
}
EOF
```

创建一个 CA 机构
```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
```

通过上定义的 CA 颁发一个 testweb.com 域名证书  ,这里创建的是一个通配符的证书
```bash
cat > ssl-csr.json <<EOF
{
  "CN": "testweb.com",
  "hosts": ["testweb.com","*.testweb.com"],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "CD",
      "ST": "CD"
    }
  ]
}
EOF
```
```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes ssl-csr.json | cfssljson -bare testweb.com
```


将证书 pem 保存到 secret
```basj
kubectl create secret tls testweb.com --cert=testweb.com.pem --key=testweb.com-key.pem
```
查看 secret
```bash
kubectl get secret
```

HTTP 和 HTTPS 配置
```bash
cat >nginx-web-ingress.yaml <<EOF
apiVersion: extensions/v1beta1 
kind: Ingress
metadata:
  name: ingress-nginx-demo
  namespace: default
  annotations: 
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
  - hosts:
    - www.testweb.com
    secretName: testweb.com
  rules:
    - host: www.testweb.com
      http:
        paths:
        - path: /
          backend:
            serviceName: nginx-demo
            servicePort: 80
EOF
```
```bash
kubectl apply -f nginx-web-ingress.yaml

```

检查 ingress
```bash
[root@node223 ~]# kubectl get ingress
NAME                HOSTS              ADDRESS   PORTS     AGE
ingress-nginx-demo   www.testweb.com              80, 443   1

```

### 修改 nginx 静态文件
```bash
[root@master01 ingress]# kubectl get pod -A |grep nginx-demo   #查找nginx-pod
default         nginx-demo-5c7f89f7b-9bvz6                        1/1     Running     0          64m

[root@master01 ingress]# kubectl exec -it nginx-demo-5c7f89f7b-9bvz6 -n default -- /bin/sh   #进入pod

/ # vi /usr/share/nginx/html/index.html    # 修改静态文件

<body>
<h1>Welcome: xxxxx </h1>
</body>
</html>

```

### 客户端访问
在 PC 上配置 honsts 将 www.testweb.com 指 k8s 控制器的 IP
![image](https://user-images.githubusercontent.com/66426170/169309256-65c68df7-e567-479c-8e11-b4feaee6f65b.png)

在浏览器里面访问这个域名的 (http\https)

![image](https://user-images.githubusercontent.com/66426170/169316660-a9990d24-f23b-43e2-938c-78e497f923c8.png)





















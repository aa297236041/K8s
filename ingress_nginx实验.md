### 实验要求：
    - ingress 的域名统一为：xxx.bktencent.com
    - 访问的页面内容统一为：Welcome: <自身的名字>
    - 暴露的端口必须为 8081，访问时为 xxxx.bktencent.com:8081
    
    
### 环境准备：
搭建k8s集群：可以参考 [k8s部署安装.md](https://github.com/aa297236041/K8s-/blob/main/k8s%E9%83%A8%E7%BD%B2%E5%AE%89%E8%A3%85.md)

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

复制以下内容执行
```bash
echo '
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---

kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: tcp-services
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: udp-services
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-ingress-serviceaccount
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: nginx-ingress-clusterrole
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - endpoints
      - nodes
      - pods
      - secrets
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  - apiGroups:
      - "extensions"
      - "networking.k8s.io"
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - "extensions"
      - "networking.k8s.io"
    resources:
      - ingresses/status
    verbs:
      - update

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: nginx-ingress-role
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - pods
      - secrets
      - namespaces
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - configmaps
    resourceNames:
      # Defaults to "<election-id>-<ingress-class>"
      # Here: "<ingress-controller-leader>-<nginx>"
      # This has to be adapted if you change either parameter
      # when launching the nginx-ingress-controller.
      - "ingress-controller-leader-nginx"
    verbs:
      - get
      - update
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - create
  - apiGroups:
      - ""
    resources:
      - endpoints
    verbs:
      - get

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: nginx-ingress-role-nisa-binding
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: nginx-ingress-role
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-serviceaccount
    namespace: ingress-nginx

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: nginx-ingress-clusterrole-nisa-binding
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nginx-ingress-clusterrole
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-serviceaccount
    namespace: ingress-nginx

---

apiVersion: apps/v1
kind: DaemonSet
#kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  #replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
    spec:
      # wait up to five minutes for the drain of connections
      terminationGracePeriodSeconds: 300
      serviceAccountName: nginx-ingress-serviceaccount
      hostNetwork: true
      nodeSelector:
        node-role.kubernetes.io/master: ""
      containers:
        - name: nginx-ingress-controller
          #image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.26.1
          image: registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller:0.23.0
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            allowPrivilegeEscalation: true
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            # www-data -> 33
            runAsUser: 33
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
            - name: https
              containerPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          lifecycle:
            preStop:
              exec:
                command:
                  - /wait-shutdown
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule

---
' >mandatory.yaml 
```

编辑mandatory.yaml
```bash
vim mandatory.yaml
```
![image](https://user-images.githubusercontent.com/66426170/169311618-53094620-dca4-404f-aec7-8bef91557782.png)


部署Ingress-Nginx
```bash
kubectl apply -f mandatory.yaml

kubectl get pods --all-namespaces |grep ingress

kubectl get pods -n ingress-nginx -o wide
```
```bash
cat >service-nodeport.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30080  #http
      protocol: TCP
    - name: https
      port: 443
      targetPort: 443
      nodePort: 30443  #https
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    
---
EOF
```
```bash
kubectl apply -f service-nodeport.yaml

kubectl get pods -n ingress-nginx -o wide

kubectl describe pod $( kubectl get pods -n ingress-nginx |grep nginx-ingress-controller |awk '{print $1}') -n ingress-nginx

kubectl get nodes --show-labels
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

创建ingress规则,HTTP配置 
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

### 如果要配置HTTPS，看下面的配置
生成证书
```bash
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/local/bin/cfssl-certinfo

chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson /usr/local/bin/cfssl-certinfo

export PATH=/usr/local/bin:$PATH
```

定义一个CA机构
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

创建一个CA机构
```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
```

通过上定义的CA颁发一个 testweb.com 域名证书  ,这里创建的是一个通配符的证书
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


将证书pem保存到secret
```basj
kubectl create secret tls testweb.com --cert=testweb.com.pem --key=testweb.com-key.pem
```
查看secret
```bash
kubectl get secret
```

HTTP 和 HTTPS配置
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

kubectl get ingress
```

检查ingress
```bash
[root@node223 ~]# kubectl get ingress
NAME                HOSTS              ADDRESS   PORTS     AGE
ingress-nginx-demo   www.testweb.com              80, 443   1

```

### 客户端访问
在pc配置honsts将www.testweb.com指k8s控制器的IP
![image](https://user-images.githubusercontent.com/66426170/169309256-65c68df7-e567-479c-8e11-b4feaee6f65b.png)

在浏览器里面访问这个域名的(http\https)



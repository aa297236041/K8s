## 介绍
通常情况下，我写的关于 Kubernetes 管理的文章中用的都是做集群管理的 kubectl 命令。然而最近，有人给我介绍了 k9s 项目，可以让我快速查看并解决 Kubernetes 中的日常问题。这极大地改善了我的工作流程，我会在这篇教程中告诉你如何上手它。

它可以安装在 Mac、Windows 和 Linux 中，每种操作系统的说明可以在这里找到。请先完成安装，以便能够跟上本教程。

我会使用 Linux 和 Minikube，这是一种在个人电脑上运行 Kubernetes 的轻量级方式。按照此教程或使用该文档来安装它。

## 下载安装

```bash
#下载
wget https://github.com/aa297236041/K8s/releases/download/k9s/k9s_Linux_x86_64.tar.gz

#解压
tar xf k9s_Linux_x86_64.tar.gz

# 移动到 bin 目录下
mv k9s /usr/bin/
```

# 执行命令验证
```bash
k9s
```
![image](https://user-images.githubusercontent.com/66426170/195751858-612cf00c-ff8d-4e5d-b74d-4ba453019ced.png)

具体使用可以网上搜索下



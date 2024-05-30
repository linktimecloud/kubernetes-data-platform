# 在 KubeSphere 容器平台安装 KDP
## KubeSphere 简介
### Kubekey

[Kubekey](https://github.com/kubesphere/kubekey) 是一个开源的 Kubernetes 安装程序和生命周期管理工具。它支持安装 Kubernetes 集群、KubeSphere 以及其他相关组件。

### KubeSphere

[KubeSphere](https://kubesphere.io/zh/) 是一个用于云原生应用程序管理的分布式操作系统，使用 Kubernetes 作为其内核。它提供了即插即用架构，允许第三方应用程序无缝集成到其生态系统中。

## 先决条件

- [x] 在 Kubernetes 已上安装 KubeSphere（快速开始可参考[在 Kubernetes 上最小化安装 KubeSphere](https://kubesphere.io/zh/docs/v3.4/quick-start/minimal-kubesphere-on-k8s/)）：
![ks-cluster-overview](./images/ks-cluster-overview.png)

- [x] KubeSphere 安装完成后，登录 KubeSphere Web 控制台并确保监控组件已启用：
![ks-monitoring](./images/ks-monitoring.png)

## 在 KubeSphere 上安装 KDP

> 假设您已经在一个 v1.26.x Kubernetes 集群上安装了 KubeSphere ，并开启了监控套件。

### 安装 KDP 命令行工具

* 可选使用本地终端工具或 KubeSphere 网页终端进行操作：
  - 通过本地 Shell：打开您计算机上的Bash或Zsh终端。
  - 通过 [Web Kubectl](https://kubesphere.io/zh/docs/v3.4/toolbox/web-kubectl/)：
![KubernetesSphere Web Kubectl](./images/ks-web-kubectl.png)

* 在网页或本地终端中，请执行以下命令以安装 KDP 命令行工具（注：若使用网页终端，因其无状态特性，每次新建立会话都需要重新安装 KDP 命令行工具）：
```bash
# 下载 KDP CLI（设置环境变量'VERSION'为所需版本号）
export VERSION=v1.1.0
wget https://github.com/linktimecloud/kubernetes-data-platform/releases/download/${VERSION}/kdp-${VERSION}-linux-amd64.tar.gz
tar xzf kdp-${VERSION}-linux-amd64.tar.gz
mkdir -p ~/.local/bin
install -v ./linux-amd64/kdp ~/.local/bin
export PATH=$PATH:$HOME/.local/bin

kdp version
```

### 安装 KDP 基础平台

执行以下命令以安装 KDP 基础平台：
```bash
# 注：请关注以下参数：
# - `openebs.enabled=false`：跳过 KDP 内置 OpenEBS hostpath provisioner 组件的安装
# - `storageConfig.storageClassMapping.localDisk=local`：使用 KubeSphere 上的内置 StorageClass，你也可以将 `local` 更改为其他现有的 SC
# - `prometheusCRD.enabled=false`：跳过 KDP 内置 Prometheus CRD 的安装
# - `prometheus.enabled=false`：跳过 KDP 内置 Prometheus Operator 的安装
# - `prometheus.externalUrl=http://prometheus-operated.kubesphere-monitoring-system.svc:9090`：使用 KubeSphere 上的内置 Prometheus 服务
kdp install \
--force-reinstall \
--set openebs.enabled=false \
--set storageConfig.storageClassMapping.localDisk=local \
--set prometheusCRD.enabled=false \
--set prometheus.enabled=false \
--set prometheus.externalUrl=http://prometheus-operated.kubesphere-monitoring-system.svc:9090 
```

## 访问 KDP UX

* 等待安装完成：
![ks-kdp-install](./images/ks-kdp-install.png)

* 转到 KubeSphere Web 控制台，并在菜单 “应用负载” -> “应用路由” 中找到名为 'kdp-ux' 的应用路由对象：
![ks-kdp-ux-ingress](./images/ks-kdp-ux-ingress.png)

* 点击并进入'kdp-ux'应用路由的详细页面，然后点击路径'/'的'访问服务'按钮，KDP UX 将在新标签页中打开：
![ks-kdp-ux-access-service](./images/ks-kdp-ux-access-service.png)

* 您现在可以使用 KDP Web 控制台来建设自己的数据平台。有关使用数据组件的更多教程，请参考[**教程目录**](./tutorials.md)：
![kdp-ux-landing-page](./images/kdp-ux-landing-page.png)

# 快速启动

用户可以在单机环境上快速体验 KDP 功能。

## 前提条件

* 单机环境的系统要求：
  - 资源配置：推荐 16C/32G内存/200G磁盘 以上（低配置环境可运行基础设施层和部分大数据组件，无法运行所有大数据组件）
  - 操作系统：Mac OS/主流 Linux 发行版
* 已安装以下软件：
  - [Docker Engine](https://docs.docker.com/engine/install/) stable
  - [Kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation) v0.18.0
  - KDP CLI（以下安装方式二选一）
    - 从 [Release Page](https://github.com/linktimecloud/kubernetes-data-platform/releases) 安装二进制
    - 编译安装 (本地需要安装 [Go](https://go.dev/doc/install) 1.21+): 克隆项目到本地, 在项目根目录执行 `go install`

## 安装 KDP 基础设施层

* 使用 KDP CLI 安装 KDP 基础设施层：
```bash
# > 指定 "--debug" 以开启debug日志
# > 指定 "--set ingress.domain=<YOUR_DOMAIN>" 单独/以及 "--set ingress.tlsSecretName=<YOUR_TLS_SECRET>" 以使用自定义域名以及TLS
# > 如安装中断, 可重复执行安装命令，已执行的步骤会自动跳过; 也可以指定 "--force-reinstall" 强制重新安装

kdp install --local-mode --set dnsService.name=kube-dns

```

## 域名解析
KDP 上运行的所有组件均通过 K8s Ingress 的方式暴露外部访问，因此安装完成后需要配置域名解析方可访问。

以下列表是 KDP 上全量组件的默认域名：
```
kdp-ux.kdp-e2e.io
grafana.kdp-e2e.io
prometheus.kdp-e2e.io
alertmanager.kdp-e2e.io
flink-session-cluster-kdp-data.kdp-e2e.io
hdfs-namenode-0-kdp-data.kdp-e2e.io
hdfs-namenode-1-kdp-data.kdp-e2e.io
hue-kdp-data.kdp-e2e.io
kafka-manager-kdp-data.kdp-e2e.io
minio-kdp-data-api.kdp-e2e.io
spark-history-server-kdp-data.kdp-e2e.io
streampark-kdp-data.kdp-e2e.io
```
域名解析配置可参考以下几种常见情况：
- 使用默认配置安装时，在访问端本地 `/etc/hosts` 添加解析以上域名解析，指向单机环境的IP地址
- 如之前指定了 "--set ingress.domain=<YOUR_DOMAIN>"，以下二选一：
  - 如自定义域名不是公网解析，替换以上所有域名的根域名为<YOUR_DOMAIN>，并在访问端本地 `/etc/hosts` 添加解析以上域名解析，指向单机环境的IP地址
  - 如自定义域名可公网解析，在DNS供应商添加以上域名的A记录，将自定义域名指向单机环境的IP地址

## 访问 KDP UX
安装完成后可访问 KDP UX，以下两种情况二选一（如指定了"--set ingress.tlsSecretName=<YOUR_TLS_SECERT>"，则使用 HTTPS 协议访问）：
- 默认配置：http://kdp-ux.kdp-e2e.io
- 指定了 "--set ingress.domain=<YOUR_DOMAIN>"：`http://kdp-ux.<YOUR_DOMAIN>`

## 环境清理

```bash
# 销毁本地集群，所有数据将被清除
kind delete cluster -n kdp-e2e

```

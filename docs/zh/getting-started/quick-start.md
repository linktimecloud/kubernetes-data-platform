# 快速启动

[English](../../en/getting-started/quick-start.md) | 简体中文

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
使用 KDP CLI 安装 KDP 基础设施层：
```bash
# if the install breaks, you may re-run the command to continue the install

kdp install --local-mode --set dnsService.name=kube-dns
```

## 配置本地域名解析
KDP 上运行的所有组件均通过 K8s Ingress 的方式暴露外部访问。在快速启动中我们使用了自定义的根域名`kdp-e2e.io`，因此安装完成后需要配置本地域名解析后方可访问对外暴露的KDP服务:
```bash
# 1. set env `KDP_HOST` to the private IP of the stand-alone host, e.g. `export KDP_HOST=192.168.1.100`
# 2. modify /etc/hosts requires sudo priviledge

kdpHost=${KDP_HOST:-127.0.0.1}
kdpDomain="kdp-e2e.io"
kdpPrefix=("kdp-ux" "grafana" "prometheus" "alertmanager" "cloudtty" "flink-session-cluster-kdp-data" "hdfs-namenode-0-kdp-data" "hdfs-namenode-1-kdp-data" "hue-kdp-data" "kafka-manager-kdp-data" "minio-kdp-data-api" "spark-history-server-kdp-data" "streampark-kdp-data")
etcHosts="/etc/hosts"

for prefix in "${kdpPrefix[@]}"; do
  domain="$prefix.$kdpDomain"
  if ! grep -q "$domain" ${etcHosts}; then
    echo "$kdpHost $domain" | sudo tee -a ${etcHosts}
  fi
done
```

## 访问 KDP UX
安装完成后可访问 KDP UX，默认地址为：http://kdp-ux.kdp-e2e.io

## 环境清理

```bash
# 1. destroy KDP kind cluster, all data will be erased
# 2. clean up /etc/hosts

kind delete cluster -n kdp-e2e
for prefix in "${kdpPrefix[@]}"; do
  sudo sed -i"" "/$prefix.$kdpDomain/d" ${etcHosts}
done
```

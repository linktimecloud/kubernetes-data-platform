# 快速启动

用户可以在单机环境上快速体验 KDP 功能。

## 前置准备

* 单机环境：
  * 配置要求：推荐 16C/32G内存/200G磁盘 以上（低配置环境可运行基础平台和部分大数据组件，无法运行所有大数据组件）
  * 操作系统：Mac OS/主流 Linux 发行版
* 已安装以下软件：
  * [Docker Engine](https://docs.docker.com/engine/install/)
  * [Kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation) v0.18.0
  * KDP CLI（以下安装方式二选一）
    * 源码编译安装：克隆项目到本地 (本地需要安装 [Go](https://go.dev/doc/install) 1.21+ 的环境)，在项目根目录执行 `go install`
    * 二进制安装：

    ```bash
    # download kdp CLI
    mkdir -p $HOME/.local/bin && \
    curl -o $HOME/.local/bin/kdp \
      "https://registry.linktimecloud.com/repository/raw/kdp/latest/kdp-$(echo $(uname -s) | tr '[:upper:]' '[:lower:]')-amd64" && \
    chmod +x $HOME/.local/bin/kdp

    # you may add next line to ~/.bashrc
    export PATH=$PATH:$HOME/.local/bin
    source ~/.bash_profile
    
    # check kdp help message
    kdp help
    ```

## 安装KDP基础平台

* 使用KDP CLI安装基础平台：

```bash
## specify '--debug' to enable verbose logging
## specify '--set K=V' parameters on-demand:
## - storageConfig.storageClassMapping.localDisk={openebs-hostpath, ...}
## - mysqlArch={standalone|replication}
## - xtrabackup.enabled={true|false}
## - kong.enabled={true|false}
## - ingress.class={kong, nginx, ...}
## - ingress.domain=kdp-e2e.io
## - ingress.tlsSecretName=
## - prometheus.enabled={true|false}
## - loki.enabled={true|false}

kdp install --local-mode --set dnsService.name=kube-dns

```

## 配置本地域名解析

```bash
# if specified '--set ingress.domain=<your-domain>' previously，
# replace below with '127.0.0.1 kdp-ux.<your-domain> grafana.<your-domain>'

sudo tee -a /etc/hosts <<EOF
127.0.0.1 kdp-ux.kdp-e2e.io grafana.kdp-e2e.io 
EOF

```

## 访问KDP界面

安装完成后，可访问 KDP 的界面，地址为：
* 默认配置：<http://kdp-ux.kdp-e2e.io>
* 指定'--set ingress.domain=<your-domain>'时：`http://kdp-ux.<your-domain>`

## 环境清理

```bash
# Destroy KIND cluster, all data will be erased.
kind delete cluster -n kdp-e2e

```

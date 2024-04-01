# 快速启动
用户可以在单机环境上快速体验 KDP 功能。

## 前置准备

* 单机环境：
  - 配置要求：推荐 16C/32G内存/100G磁盘 以上（低配置环境可运行基础平台和部分大数据组件，无法运行所有大数据组件）
  - 操作系统：Mac OS/主流 Linux 发行版
* 已安装以下软件：
  - [Docker Engine(stable)](https://docs.docker.com/engine/install/)
  - [Kind(v0.18.0)](https://github.com/kubernetes-sigs/kind/releases/tag/v0.18.0)
  - KDP CLI（以下安装方式二选一）
    - 源码编译安装(go 1.21+)：`go install`
    - 二进制安装：
    ```bash
    # download kdp binary
    sudo curl -o /usr/local/bin/kdp \
      "https://registry.linktimecloud.com/repository/raw/kdp/latest/kdp-$(echo $(uname -s) | tr '[:upper:]' '[:lower:]')-amd64" \
      && sudo chmod +x /usr/local/bin/kdp
    
    # check kdp help message
    kdp help
    ```

## 安装KDP基础平台

* 使用KDP CLI安装基础平台：
```bash
## Common parameters:
## - storageConfig.storageClassMapping.localDisk=openebs-hostpath
## - mysqlArch={standalone|replication}
## - xtrabackup.enabled={true|false}
## - kong.enabled={true|false}
## - ingress.class={kong, nginx, ...}
## - ingress.domain=kdp-e2e.io
## - ingress.tlsSecretName=
## - prometheus.enabled={true|false}
## - loki.enabled={true|false}

## specify '--set prometheus.enabled=false --set loki.enabled=false' to disable prometheus and loki on limited resources environment
## specify '--debug' to enable verbose logging
kdp install --local-mode --set dnsService.name=kube-dns

```

* 更新KDP基础平台配置参数：
```bash
kdp update --set mysqlDiskSize=20Gi

```

## 配置本地域名解析
```bash
# 如安装或更新指定了'--set ingress.domain=<your-domain>'的选项，
# 这里替换为'127.0.0.1 kdp-ux.<your-domain> grafana.<your-domain>'
sudo tee -a /etc/hosts <<EOF
127.0.0.1 kdp-ux.kdp-e2e.io grafana.kdp-e2e.io 
EOF

```

## 访问KDP界面
使用默认配置安装完成后，KDP界面的地址为：http://kdp-ux.kdp-e2e.io ；
如安装或更新指定了'--set ingress.domain=<your-domain>'的选项，界面地址为：http://kdp-ux.<your-domain> 。

## 环境清理
```bash
# Destroy KIND cluster, all data will be erased.
kind delete cluster -n kdp-e2e

```

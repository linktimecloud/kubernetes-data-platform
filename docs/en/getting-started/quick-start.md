---
id: quick-start
---

# Quick Start

English | [简体中文](../../zh/getting-started/quick-start.md)

Users can quickly experience KDP functions on a stand-alone environment.

## Pre-requisite

* System requirements of the stand-alone machine: 
  - Resources: >=[16 Core/32G RAM/200G Disk] is recommended(low setup may run KDP infrastructure and part of the big data components, but not all the components)
  - Operating system: Mac OS/ major Linux distribution
* Below software already installed：
  - [Docker Engine](https://docs.docker.com/engine/install/) stable
  - [Kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation) v0.18.0
  - KDP CLI(select one of the following installation methods)
    - Binary installation from [Release Page](https://github.com/linktimecloud/kubernetes-data-platform/releases)
    - Source code installation (requires [Go](https://go.dev/doc/install) 1.21+ installed locally): clone the project to the local, then run `go install` at project root

## Install KDP Infrastructure

* Use KDP CLI to install KDP infrastructure:
```bash
# > specify "--debug" to enable verbose logging
# > if the install breaks, you may re-run the command to continue the install
kdp install --local-mode --set dnsService.name=kube-dns
```

## Local Domain resolution

All components running on the KDP are exposed to external access through the K8s Ingress. We used a self-defined root domain `kdp-e2e.io` for the quick start, therefore, local domain resolution must be configured in order to visit those services:
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

## Visit KDP UX
After the installation is completed successfully, you may visit KDP UX by the default URL：http://kdp-ux.kdp-e2e.io

## Clean up
```bash
# 1. destroy KDP kind cluster, all data will be erased
# 2. clean up /etc/hosts

kind delete cluster -n kdp-e2e
for prefix in "${kdpPrefix[@]}"; do
  sudo sed -i"" "/$prefix.$kdpDomain/d" ${etcHosts}
done
```

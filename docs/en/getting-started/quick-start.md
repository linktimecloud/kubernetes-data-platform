# Quick Start
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

## Install KDP

* Use KDP CLI to install KDP infrastructure:
```bash
# > specify "--debug" to enable verbose logging
# > specify "--set ingress.domain=<YOUR_DOMAIN>" w/wo "--set ingress.tlsSecretName=<YOUR_TLS_SECRET>" to use your own domain w/wo TLS
# > if the install breaks, you may run the command again and it will skip the steps already been done; you may also specify "--force-reinstall" to do a start-over force reinstallation

kdp install --local-mode --set dnsService.name=kube-dns

```

## Domain resolution

All components running on the KDP are exposed to external access through the K8s Ingress. Therefore, domain name resolution must be configured after the installation.

Below is a list of domains for all components on KDP by default:
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

You may refer to the following common scenarios for configuring domain resolution:
- when installing with the default configuration, add the resolution of the above domains to the local `/etc/hosts` on the access end, pointing to the IP address of the stand-alone environment
- if specified "--set ingress.domain=<YOUR_DOMAIN>" previously, choose one of the following：
  - if the customized domains are not public resolved, replace the root domain of the above domains with "<YOUR_DOMAIN>", then add the resolution of the above domains to the local `/etc/hosts` on the access end, pointing to the IP address of the stand-alone environment
  - elsely, add A records of above domains at DNS provider, pointing to the IP address of the stand-alone environment

## Visit KDP UX
After the installation is complete, you can access the KDP UX in either of the following situations(if specified "--set ingress.tlsSecretName=<YOUR_TLS_SECERT>" previously, use HTTPS protocol)：
- by default：http://kdp-ux.kdp-e2e.io
- with '--set ingress.domain=<YOUR_DOMAIN>'：`http://kdp-ux.<YOUR_DOMAIN>`

## Clean up
```bash
# destroy local cluster, all data will be erased.
kind delete cluster -n kdp-e2e

```

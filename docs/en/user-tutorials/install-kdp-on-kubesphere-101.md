# Install KDP on KubeSphere Container Platform

## KubeSphere Container Platform

[Kubekey](https://github.com/kubesphere/kubekey) is an open source Kubernetes installer and lifecycle manager. It supports installation of Kubernetes clusters, KubeSphere, and other related components.

[KubeSphere](https://kubesphere.io/) is a distributed operating system for cloud-native application management, using Kubernetes as its kernel. It provides a plug-and-play architecture, allowing third-party applications to be seamlessly integrated into its ecosystem.

Together, they provide a complete solution for a cloud-native application platform, including container management, DevOps, service mesh, and observability.

## Prerequisites

- KubeSphere installed on Kubernetes v1.26.x (refer to [Minimal KubeSphere on Kubernetes](https://kubesphere.io/docs/v3.4/quick-start/minimal-kubesphere-on-k8s/) for a quick-start):
![ks-cluster-overview](./images/ks-cluster-overview.png)
- After KubeSphere is installed, login to KubeSphere web console and make sure the monitoring component (this will install the Prometheus operator, a Prometheus cluster and an Alertmanager cluster) is enabled:
![ks-monitoring](./images/ks-monitoring.png)

## Install KDP on KubeSphere

1. Log in to KubeSphere web console with the admin account.
2. Use [Web Kubectl](https://kubesphere.io/docs/v3.4/toolbox/web-kubectl/) function to open a web terminal:
![ks-web-kubectl](./images/ks-web-kubectl.png)
1. In the web terminal, run below commands to install KDP:
```bash
# Download KDP CLI
export VERSION=v1.1.0
wget https://github.com/linktimecloud/kubernetes-data-platform/releases/download/${VERSION}/kdp-${VERSION}-linux-amd64.tar.gz
tar xzf kdp-${VERSION}-linux-amd64.tar.gz
mkdir -p ~/.local/bin
install -v linux-amd64/kdp ~/.local/bin
export PATH=$PATH:$HOME/.local/bin
kdp version

# Install KDP
# Note: pay attention to those parameters:
# - `openebs.enabled=false`: To disable installing OpenEBS hostpath provisioner in KDP
# - `storageConfig.storageClassMapping.localDisk=local`: To use the built-in StorageClass on KubeShpere, you may also change `local` to other existing SC
# - `prometheusCRD.enabled=false`: To disable installing Prometheus CRD in KDP
# - `prometheus.enabled=false`: To disable installing Prometheus operator and cluster in KDP
# - `prometheus.externalUrl=http://prometheus-operated.kubesphere-monitoring-system.svc:9090`: To use the built-in Prometheus service URL on KubeShpere
kdp install \
--force-reinstall \
--set openebs.enabled=false \
--set storageConfig.storageClassMapping.localDisk=local \
--set prometheusCRD.enabled=false \
--set prometheus.enabled=false \
--set prometheus.externalUrl=http://prometheus-operated.kubesphere-monitoring-system.svc:9090
```
4. Wait for the installation to complete:
![ks-kdp-install](./images/ks-kdp-install.png)

## Visit KDP web console

1. After KDP installation is completed, go to the KubeSphere web console and find the ingress object named 'kdp-ux' in menu 'Application Workloads' -> 'Ingresses':
![ks-kdp-ux-ingress](./images/ks-kdp-ux-ingress.png)

2. Click and entering the detail page of ingress 'kdp-ux', then click the 'Access Service' button of path '/' and KDP web console will be opened in a new tab
![ks-kdp-ux-access-service](./images/ks-kdp-ux-access-service.png)

3. You may now use KDP web console to set up your data platform. For more tutorials with data components, please refer to [tutorials](./tutorials.md).

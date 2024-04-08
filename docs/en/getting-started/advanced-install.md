# Advanced Installation

Users can quickly deploy KDP on an existing Kubernetes cluster using the CLI.

## Resource planning

* Required: Existing Kubernetes cluster >=1.26 (public cloud or on-premise), the recommended configuration is:
  * Control plane: 8vCPUs 16GB RAM * 3 (control-plane HA)
  * Work node: 8vCPUs 16GB RAM >= 4, if K8s persistent volumes use node local disks, disks can be mounted to `/var/lib/openebs` directory (`/var/lib/openebs` is the default storage volume directory of KDP)
* Optional: Existing public domain resolution and TLS certificate for KDP service exposure and external access (if no public domain resolution and TLS certificate are available, please refer to the "Domain resolution" section in [Quick Start](./quick-start.md) configuring domain resolution on both the access side and K8s cluster [CoreDNS] (https://coredns.io/plugins/hosts/) side)

## Pre-requisite

* The [kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) with cluster-role [priviledge]((https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)) is ready at `$HOME/.kube/config` on the machine to install KDP infrastructure
* KDP CLI is ready on the machine to install KDP infrastructure(select one of the following installation methods)
  - Binary installation from [Release Page](https://github.com/linktimecloud/kubernetes-data-platform/releases)
  - Source code installation (requires [Go](https://go.dev/doc/install) 1.21+ installed locally): clone the project to the local, then run `go install` at project root

## Install KDP infrastructure layer

### Install with the default configuration
Single-command install by KDP CLI：
```bash
# > specify "--debug" to enable debug logging
kdp install
```

### Supported runtime parameters
Runtime parameters are supported via "--set k1=v1 --set k2=v2 ..." when install or upgrade. All supported runtime parameters are as follows (all are optional parameters) :

| Parameters | Description | Default Value | Support Update or not | Notes |
| --- | --- | --- | --- | --- |
| namespace | The namespace in which the KDP infrastructure layer services are installed | kdp-system | N | A force update after installation will cause services to be redeployed to the new namespace and volumes to be reclaimed, resulting in data loss |
| imagePullSecret | Image pulling secret name | cr-secret | Y | |
| storageConfig.storageClassMapping.localDisk | The name of the storage class to use for the KDP volume claiming  | openebs | N | - If you need to use an existing storage class (such as the cloud disk CSI provided by the public cloud K8s products, etc.), you can specify this parameter during installation <br> - A force update will cause the storage volume to be re-claimed, resulting in data loss |
| kong.enabled | Whether to install Kong Ingress | true | Y | If you want to use an existing Ingress Controller on the K8s cluster, set it to 'false', also set the 'ingress.class' as existing [IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class) name |
| kong.replicas | Kong Ingress replicas | 4 | Y | |
| ingress.class | IngressClass used by KDP Ingress | kong | Y | |
| ingress.domain | The root domain used by KDP Ingress | kdp-e2e.io | Y | This parameter can be set if a custom domain name is used |
| ingress.tlsSecretName | TLS secret used by the KDP Ingress | "" | Y | This parameter can be set if a custom domain name and [TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls) are used |
| prometheusCRD.enabled | Whether to install Prometheus Operator CRD | true | Y | You may turn this off if you want to use existing [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) on K8s cluster |
| prometheus.enabled | Whether to install Prometheus Operator/Prometheus/Alertmanager/Grafana | true | Y | You may turn this off if you want to use existing [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) on K8s cluster |
| prometheus.externalUrl | The Prometheus service address used by the KDP observability feature | "" | Y | Set only when using external Prometheus service |
| loki.enabled | Whether to install Loki | true | Y | You may turn this off if you want to use existing Loki service on K8s cluster |
| loki.externalUrl | The Loki service address used by the KDP observability feature | "" | Y | Set only when using external Loki service |
| grafana.externalUrl | The Grafana service address used by the KDP observability feature | "" | Y | Set only when using external Grafana service |
| mysqlArch | The architecture used by KDP built-in MySQL | standalone | N | - can be specified as `replication` if using primary-secondary replication mode <br> - A force update will cause MySQL volumes to be reclaimed resulting in data loss |
| mysqlDiskSize | The storage size claimed by KDP built-in MySQL | 10Gi | N | Force updates will not take effect after installation, as K8s StatefulSets workloads do not support dynamic update of storage volume size |
| xtrabackup.enabled | Whether to install MySQL XtraBackup | false | Y | Backup data by enabling XtraBackup container on MySQL Pod |
| xtrabackup.diskSize | Backup storage volume size for MySQL XtraBackup | 10Gi | N | Force updates will not take effect after installation, as K8s StatefulSets workloads do not support dynamic update of storage volume size |
| systemMysql.debug | Whether to enable debug logging for KDP built-in MySQL  | false | Y | |
| systemMysql.host | MySQL service address used by the KDP infrastructure services | mysql | Y | - Do not set if using KDP built-in MySQL <br> - Set only when using external MySQL service |
| systemMysql.port | MySQL service port used by the KDP infrastructure services | 3306 | Y | - Do not set if using KDP built-in MySQL <br> - Set only when using external MySQL service |
| systemMysql.users.root.user | root user name of KDP built-in MySQL | root | N | - Effective only when using KDP built-in MySQL <br> - A force update after installation will cause KDP built-in MySQL workloads to operate abnormally |
| systemMysql.users.root.password | root user password of KDP built-in MySQL(base64 encoded) | a2RwUm9vdDEyMyo= | N | - Effective only when using KDP built-in MySQL <br> - A force update after installation will cause KDP built-in MySQL workloads to operate abnormally |
| systemMysql.users.kdpAdmin.user | MySQL user name used by the KDP infrastructure services | kdpAdmin | Y | - If using KDP built-in MySQL, the user will be automatically created <br> - If using external MySQL, specify the corresponding user name |
| systemMysql.users.kdpAdmin.password | MySQL user password used by the KDP infrastructure services(base64 encoded) | a2RwQWRtaW4xMjMq | Y | - If using KDP built-in MySQL, the user password will be automatically set <br> - If using external MySQL, specify the corresponding user password |
| dnsService.name | The DNS service name used by KDP logging gateway for service discovery | coredns | Y | Used in conjunction with the `dnsService.namespace` parameter, only specified if the DNS service of the K8s cluster does not use CoreDNS |
| dnsService.namespace | The DNS service namespace used by KDP logging gateway for service discovery | kube-system | Y | |

## Visit KDP UX
After the installation is complete, you can access the KDP UX in either of the following situations(if specified "--set ingress.tlsSecretName=<YOUR_TLS_SECERT>" previously, use HTTPS protocol)：
- by default：http://kdp-ux.kdp-e2e.io
- with '--set ingress.domain=<YOUR_DOMAIN>'：`http://kdp-ux.<YOUR_DOMAIN>`

## Upgrade KDP infrastructure layer
Single-command upgrade by KDP CLI：
```bash
# > specify "--debug" to enable debug logging
# > specify "--src-upgrade" to upgrade the latest KDP infrastructure manifests
# > specify "--vela-upgrade" to upgrade KDP Vela service
# > specify "--set k1=v1 --set k2=v2 ..." to upgrade runtime parameters of KDP infrastructure
kdp upgrade --set k1=v1 --set k2=v2 ...
```

## Install KDP big data application layer
When the KDP infrastructure layer is installed, users can install KDP big data application layer components through the web interface by KDP UX.

KDP built-in application catalogs can be referred to：[Catalog Overview](../catalog-overview/catalogs.md)

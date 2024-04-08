# 高级安装

用户可在已有的 Kubernetes 集群上通过CLI快速部署 KDP。

## 资源规划

* 必需：已有一个 Kubernetes 集群 >=1.26（公有云或自建），建议配置为：
  * 控制平面：8vCPUs 16GB RAM * 3台（控制平面高可用）
  * 工作节点：8vCPUs 16GB RAM >= 4台，如 K8s 存储卷使用节点本地盘可挂载到`/var/lib/openebs`目录（`/var/lib/openebs`为 KDP 默认的存储卷目录）
* 可选：已有公网解析域名及TLS证书，用于 KDP 服务暴露及外部访问（如不具备公网解析域名及TLS证书，可参考[快速启动](./quick-start.md)中“域名解析”章节在访问端及集群 [CoreDNS](https://coredns.io/plugins/hosts/) 配置自定义域名解析）

## 前提条件

* 执行部署 KDP 的节点已准备好位于`$HOME/.kube/config`路径的[kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)，kubeconfig具备集群管理员[权限](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)
* 执行部署 KDP 的节点已安装 KDP CLI（以下安装方式二选一）
    - 从 [Release Page](https://github.com/linktimecloud/kubernetes-data-platform/releases) 安装二进制
    - 编译安装 (本地需要安装 [Go](https://go.dev/doc/install) 1.21+): 克隆项目到本地, 在项目根目录执行 `go install`

## 安装 KDP 基础设施层

### 使用默认配置安装
命令行一键安装：
```bash
# > 指定 "--debug" 可开启debug日志
kdp install
```

### 支持的运行时参数
安装或更新时支持通过"--set k1=v1 --set k2=v2 ..."的方式指定运行时参数；支持的运行时参数如下（所有参数均为可选参数）：

| 参数 | 描述 | 默认值 | 是否支持更新 | 说明 |
| --- | --- | --- | --- | --- |
| namespace | KDP基础设施层服务安装的命名空间 | kdp-system | 否 | 安装后强制更新会导致服务重新部署到新的命名空间，存储卷会重新申领从而导致数据丢失 |
| imagePullSecret | 镜像拉取密钥名 | cr-secret | 是 | |
| storageConfig.storageClassMapping.localDisk | KDP 存储卷申请使用的存储类名称 | openebs | 否 | - 如需使用已有存储类（例如公有云 K8s 产品提供的动态云盘存储类等），安装时可指定该参数 <br> - 强制更新会导致存储卷重新申领从而导致数据丢失 |
| kong.enabled | 是否安装 Kong Ingress | true | 是 | 如需使用 K8s 集群上已有的 Ingress Controller，可设置为`false`，同时将`ingress.class`设置为已有的 [IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class) 名称 |
| kong.replicas | Kong Ingress 的副本数 | 4 | 是 | |
| ingress.class | KDP Ingress 使用的 IngressClass | kong | 是 | |
| ingress.domain | KDP Ingress 使用的根域名 | kdp-e2e.io | 是 | 如启用自定义域名，可设置该参数 |
| ingress.tlsSecretName | KDP Ingress 使用的 TLS secret | "" | 是 | 如启用自定义域名及 [TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls) ，可设置该参数 |
| prometheusCRD.enabled | 是否安装 Prometheus Operator CRD | true | 是 | 如需使用 K8s 集群上已有的 [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) ，可关闭 |
| prometheus.enabled | 是否安装 Prometheus Operator/Prometheus/Alertmanager/Grafana | true | 是 | 如需使用 K8s 集群上已有的 [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) ，可关闭 |
| prometheus.externalUrl | KDP 可观测性功能使用的 Prometheus 服务地址 | "" | 是 | 仅当使用外部 Prometheus 服务时设置 |
| loki.enabled | 是否安装 Loki | true | 是 | 如需使用 K8s 集群上已有的 Loki 服务，可关闭 |
| loki.externalUrl | KDP 可观测性功能使用的 Loki 服务地址   | "" | 是 | 仅当使用外部 Loki 服务时设置 |
| grafana.externalUrl | KDP 可观测性功能使用的 Grafana 服务地址 | "" | 是 | 仅当使用外部 Grafana 服务时设置 |
| mysqlArch | KDP 内置 MySQL 使用的架构 | standalone | 否 | - 使用主从复制架构可指定为`replication` <br> - 强制更新会导致 MySQL 存储卷重新申领从而导致数据丢失 |
| mysqlDiskSize | KDP 内置 MySQL 使用的存储卷大小 | 10Gi | 否 | 安装后强制更新不会生效，K8s StatefulSets 类型工作负载不支持动态更新存储卷大小 |
| xtrabackup.enabled | 是否安装 MySQL XtraBackup 工具 | false | 是 | 通过在 MySQL Pod 上开启 XtraBackup 容器进行数据备份 |
| xtrabackup.diskSize | MySQL XtraBackup 挂载的备份存储卷大小 | 10Gi | 否 | 安装后强制更新不会生效，K8s StatefulSets 类型工作负载不支持动态更新存储卷大小 |
| systemMysql.debug | KDP 内置 MySQL 开启调试日志 | false | 是 | |
| systemMysql.host | KDP 基础服务使用的 MySQL 服务地址 | mysql | 是 | - 如使用 KDP 内置 MySQL 时不需要设置 <br> - 如使用外部 MySQL，可指定为外部 MySQL 服务的地址 |
| systemMysql.port | KDP 基础服务使用的 MySQL 服务端口 | 3306 | 是 | - 如使用 KDP 内置 MySQL 时不需要设置 <br> - 如使用外部 MySQL，可指定为外部 MySQL 服务的端口 |
| systemMysql.users.root.user | KDP 内置 MySQL root 用户名 | root | 否 | - 仅使用 KDP 内置 MySQL 时生效 <br> - 安装后强制更新会导致 KDP 内置 MySQL 工作负载运行异常 |
| systemMysql.users.root.password | KDP 内置 MySQL root 用户密码（base64编码） | a2RwUm9vdDEyMyo= | 否 | - 仅使用 KDP 内置 MySQL 时生效 <br> - 安装后强制更新会导致 KDP 内置 MySQL 工作负载运行异常 |
| systemMysql.users.kdpAdmin.user | KDP 基础服务使用的 MySQL 用户名 | kdpAdmin | 是 | - 如使用 KDP 内置 MySQL 会自动创建用户 <br> - 如使用外部 MySQL，可指定为对应的用户名 |
| systemMysql.users.kdpAdmin.password | KDP 基础服务使用的 MySQL 用户密码（base64编码） | a2RwQWRtaW4xMjMq | 是 | - 如使用 KDP 内置 MySQL 会自动设置用户密码 <br> - 如使用外部 MySQL，可指定为对应的用户密码 |
| dnsService.name | KDP 日志网关自动发现所使用的 DNS service 名称 | coredns | 是 | 配合`dnsService.namespace`参数使用，仅当 K8s 集群的 DNS 服务不使用 CoreDNS 时指定 |
| dnsService.namespace | KDP 日志网关自动发现所使用的 DNS service 命名空间 | kube-system | 是 | |

## 访问 KDP UX
安装完成后可访问 KDP UX，以下两种情况二选一（如指定了"--set ingress.tlsSecretName=<YOUR_TLS_SECERT>"，则使用 HTTPS 协议访问）：
- 默认配置：http://kdp-ux.kdp-e2e.io
- 指定了 "--set ingress.domain=<YOUR_DOMAIN>"：`http://kdp-ux.<YOUR_DOMAIN>`

## 更新 KDP 基础设施层
命令行一键更新：
```bash
# > 指定 "--debug" 可开启debug日志
# > 指定 "--src-upgrade" 更新 KDP 基础设施层最新配置清单
# > 指定 "--vela-upgrade" 更新 KDP Vela 服务
# > 指定 "--set k1=v1 --set k2=v2 ..." 更新 KDP 基础设施层运行时参数
kdp upgrade --set k1=v1 --set k2=v2 ...
```

## 安装 KDP 大数据应用层
当 KDP 基础设施层安装完成后，用户可通过访问 KDP UX 以界面化的方式安装 KDP 大数据应用层组件;

KDP 内置支持的应用目录可参考：[应用目录概览](../catalog-overview/catalogs.md)

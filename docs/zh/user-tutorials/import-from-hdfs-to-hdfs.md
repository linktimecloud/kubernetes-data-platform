# 从外部 HDFS 导入数据到 KDP HDFS

从老集群迁移数据到新集群是一个常见需求。在传统模式部署的 HDFS 集群上可以使用 [distcp](https://hadoop.apache.org/docs/current/hadoop-distcp/DistCp.html) 进行数据迁移。但 KDP 上没有 YARN，无法直接使用 distcp 进行数据迁移。作为替代，我们可以使用 [spark-distcp](https://index.scala-lang.org/coxautomotivedatasolutions/spark-distcp) 进行数据迁移。

# 组件依赖

请安装以下组件：

- spark-on-k8s-operator

# 进行数据迁移

假设老集群的 HDFS 开启了 Namenode 高可用，地址分别为

- hdfs://namenode-1:8020
- hdfs://namenode-2:8020

KDP 上的 HDFS Namenode 地址则分别为

- hdfs-namenode-0.hdfs-namenode.kdp-data.svc.cluster.local:8020
- hdfs-namenode-1.hdfs-namenode.kdp-data.svc.cluster.local:8020

我们将老集群的 hdfs:///data 目录迁移到 KDP HDFS 集群上的 hdfs:///data。

在本地创建文件 `spark-distcp.yaml`，内容如下：

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-distcp
  namespace: kdp-data
spec:
  type: Scala
  mode: cluster
  image: od-registry.linktimecloud.com/ltc-spark:v1.0.0-3.3.0
  sparkVersion: 3.3.0
  mainClass: com.coxautodata.SparkDistCP
  mainApplicationFile: https://repo1.maven.org/maven2/com/coxautodata/spark-distcp_2.12/0.2.5/spark-distcp_2.12-0.2.5-assembly.jar
  hadoopConf:
    "dfs.nameservices": "source,target"
    "dfs.ha.namenodes.source": "nn0,nn1"
    "dfs.namenode.rpc-address.source.nn0": "hdfs://namenode-1:8020"
    "dfs.namenode.rpc-address.source.nn1": "hdfs://namenode-2:8020"
    "dfs.client.failover.proxy.provider.source": "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider"
    "dfs.ha.namenodes.target": "nn0,nn1"
    "dfs.namenode.rpc-address.target.nn0": "hdfs-namenode-0.hdfs-namenode.kdp-data.svc.cluster.local:8020"
    "dfs.namenode.rpc-address.target.nn1": "hdfs-namenode-1.hdfs-namenode.kdp-data.svc.cluster.local:8020"
    "dfs.client.failover.proxy.provider.target": "org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider"
  driver:
    cores: 1
    memory: 512m
  executor:
    cores: 1
    instances: 2
    memory: 512m
  arguments:
    - hdfs://source/data
    - hdfs://target/data
```

注意 `spec.hadoopConf` 中的内容，我们将老集群命名为 `source`，KDP HDFS 集群命名为 `target`。

driver 和 executor 的资源可以按需要调整。

执行以下命令开始进行数据迁移：

```shell
kubectl apply -f spark-distcp.yaml
```

迁移进度可以查看 `spark-distcp-driver` pod 的日志，或者通过以下命令从本地浏览器访问 Spark UI:

```shell
# 执行完毕后可以从浏览器访问 localhost:4040
kubectl port-forward spark-distcp-driver -n kdp-data 4040:4040
```

更多参数和注意事项可以参考 https://index.scala-lang.org/coxautomotivedatasolutions/spark-distcp

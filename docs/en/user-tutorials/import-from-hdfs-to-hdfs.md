# Data Import from External HDFS to KDP HDFS

Migrating data from an old cluster to a new cluster is a common requirement. On a traditional HDFS cluster deployment, you can use [distcp](https://hadoop.apache.org/docs/current/hadoop-distcp/DistCp.html) for data migration. However, since KDP does not have YARN, you cannot directly use distcp for data migration. As an alternative, you can use [spark-distcp](https://index.scala-lang.org/coxautomotivedatasolutions/spark-distcp) for data migration.

# Component Dependencies

Please install the following components:

- spark-on-k8s-operator

# Performing Data Migration

Assuming the HDFS on the old cluster has Namenode High Availability enabled, with addresses as follows:

- hdfs://namenode-1:8020
- hdfs://namenode-2:8020

The HDFS Namenode addresses on KDP are:

- hdfs-namenode-0.hdfs-namenode.kdp-data.svc.cluster.local:8020
- hdfs-namenode-1.hdfs-namenode.kdp-data.svc.cluster.local:8020

We will migrate the directory hdfs:///data from the old cluster to hdfs:///data on the KDP HDFS cluster.

Create a file `spark-distcp.yaml` with the following content on your local machine:

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

Pay attention to the contents in `spec.hadoopConf`. We named the old cluster as `source` and the KDP HDFS cluster as `target`.

You can adjust the resources for the driver and executor as needed.

Execute the following command to start the data migration process:

```shell
kubectl apply -f spark-distcp.yaml
```

Migration progress can be viewed by checking the logs of the `spark-distcp-driver` pod, or by accessing the Spark UI from a local browser using the following command:

```shell
# Once executed, you can access localhost:4040 from your browser
kubectl port-forward spark-distcp-driver -n kdp-data 4040:4040
```

For more parameters and considerations, you can refer to https://index.scala-lang.org/coxautomotivedatasolutions/spark-distcp
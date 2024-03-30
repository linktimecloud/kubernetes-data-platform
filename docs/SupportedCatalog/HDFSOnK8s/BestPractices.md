# HDFS 最佳实践

## JVM 内存调优

以下为您介绍如何调整 NameNode JVM 和 DataNode JVM 内存大小，以便优化 HDFS 的稳定性。

### 调整 NameNode JVM 内存大小

在 HDFS 中，每个文件对象都需要在 NameNode 中记录元数据信息，并占用一定的内存空间。默认的 JVM 配置可以满足部分普通的 HDFS 使用。部分 Workload 会向 HDFS 中写入更多文件， 或者随着一段时间的积累 HDFS 保存的文件数不断增加，当增加的文件数超过默认的内存空间配置时，则默认的内存空间无法存储相应的信息，您需要修改内存大小的设置。

修改 NameNode JVM 内存大小。您可以在 KDP 的 HDFS 应用的配置页面，修改 Namenode 节点下的 maxRAMPercentage。这个参数相当于 JVM 的参数 `-XX:MaxRAMPercentage`，注意必须是浮点数，如 `60.0`。修改后，JVM 内存就为 **容器内存 x 60%**，即 `resources.limits.memory * maxRAMPercentage`。

您可以通过访问 HDFS UI 页面，查看文件数 Files 和文件块数 Blocks。您可以根据以下计算方法调整 NameNode JVM 内存大小。

> 建议值 =（ 文件数（以百万为单位）+块数（以百万为单位））× 512 MB

例如，您有 1000 万个文件，都是中小文件且不超过 1 个 Block，Blocks 数量也为 1000 万，则内存大小建议值为 10240 MB，即（10+10）× 512 MB。当您的大多数文件不超过 1 个 Block 时，建议值如下。

| 文件数量    | 建议值(MB) |
| ----------- | ---------- |
| 10,000,000  | 10240      |
| 20,000,000  | 20480      |
| 50,000,000  | 51200      |
| 100,000,000 | 102400     |

### 调整 DataNode JVM 内存大小

在 HDFS 中，每个文件 Block 对象都需要在 DataNode 中记录 Block 元数据信息，并占用一定的内存空间。默认的 JVM 配置可以满足部分简单的、压力不大的作业需求。而部分作业会向 HDFS 写入更多的文件， 或者随着一段时间的积累 HDFS 保存的文件数不断增加。当文件数增加，DataNode 上的 Block 数也会增加，而默认的内存空间无法存储相应的信息时，则需要修改内存大小的设置。

您可以在 KDP 的 HDFS 应用的配置页面，修改 Datanode 节点下的 maxRAMPercentage。这个参数相当于 JVM 的参数 `-XX:MaxRAMPercentage`，注意必须是浮点数，如 `60.0`。修改后，JVM 内存就为 **容器内存 x 60%**，即 `resources.limits.memory * maxRAMPercentage`。

您可以根据以下计算方法调整 DataNode JVM 内存大小。
> 集群中每个 DataNode 实例平均保存的副本数 Replicas = 文件块数 Blocks × 3 ÷ DataNode 节点数
> 建议值 = 单个 DataNode 副本数 Replicas（百万单位）× 2048 MB

例如，大数据机型为 3 副本，Core 节点数量为 6，如果您有 1000 万个文件且都是中小文件，Blocks 数量也为 1000 万，则单个 DataNode 副本数 Replicas 为 500 万（1000 万× 3 ÷ 6）， 内存大小建议值为 10240 MB（5 × 2048 MB）。

当您的大多数文件不超过 1 个 Block 时，建议值如下。

| 单个 DataNode 实例平均 Replicas 数量 | 建议值(MB) |
| ------------------------------------ | ---------- |
| 10,000,000                           | 2048       |
| 20,000,000                           | 4096       |
| 50,000,000                           | 10240      |

## 实时计算场景优化

### 调整 DataNode Xceiver 连接数

通常实时计算框架会打开较多的 HDFS 文件写入流（Stream），方便不断地向 HDFS 写入新的数据。HDFS 允许同时打开的文件数量是有限的，受限于 DataNode 参数 `dfs.datanode.max.transfer.threads`。

您可以在 KDP 的 HDFS 应用的配置页面，在 hdfsSite 节点内修改 `dfs.datanode.max.transfer.threads`，该参数表示 DataNode 处理读或写流的线程池大小。当您在日志目录下或者客户端运行日志中发现如下报错时，可以适当地调大该参数值：

在 DataNode 服务端日志，发现如下报错

```log
java.io.IOException: Xceiver count 4097 exceeds the limit of concurrent xcievers: 4096
        at org.apache.hadoop.hdfs.server.datanode.DataXceiverServer.run(DataXceiverServer.java:150)
```

在客户端运行日志中发现如下报错

```log
DataXceiver error processing WRITE_BLOCK operation  src: /10.*.*.*:35692 dst: /10.*.*.*:50010
java.io.IOException: Premature EOF from inputStream
```

### 配置预留磁盘空间

HDFS 对于打开的文件写入流，会预先保留 128 MB Blocksize 的磁盘剩余空间，从而确保该文件可以正常写入。如果该文件实际大小很小，例如仅为 8 MB，则当文件调用 close 方法关闭输入流时只会占用 8 MB 的磁盘空间。

通常实时计算框架会打开较多的 HDFS 文件写入流，如果同时打开很多文件， 则 HDFS 会预先保留较多的磁盘空间。如果磁盘剩余空间不够，则会导致创建文件失败。

如果同时打开的文件数为 N，则集群至少需要预留的磁盘空间为 N * 128 MB * 副本数。

## HDFS 使用优化

### 控制小文件个数

HDFS NameNode 将所有文件元数据加载在内存中，在集群磁盘容量一定的情况下，如果小文件个数过多，则会造成 NameNode 的内存容量瓶颈。

尽量控制小文件的个数。对于存量的小文件，建议合并为大文件。

### 配置 HDFS 单目录文件数量

当集群运行时，不同组件（例如 Spark）或客户端可能会向同一个 HDFS 目录不断写入文件。但 HDFS 系统支持的单目录文件数目是有上限的，因此需要您提前做好规划，防止单个目录下的文件数目超过阈值，导致任务出错。

您可以在 KDP 的 HDFS 应用的配置页面，hdfsSite 节点内新增参数 `dfs.namenode.fs-limits.max-directory-items`，以设置单个目录下可以存储的文件数目，最后保存配置。

您需要将数据做好存储规划，可以按时间、业务类型等分类，单个目录下直属的文件不要过多，建议单个目录下约 100 万条。

### 配置可容忍的磁盘坏卷

如果为 DataNode 配置多个数据存放卷，默认情况下其中一个卷损坏，则 DataNode 将不再提供服务。

您可以在 KDP 的 HDFS 应用的配置页面，hdfsSite 节点内新增参数 `dfs.datanode.failed.volumes.tolerated`，您可以设置此参数，小于该参数值，DataNode 可以继续提供服务。

| 参数             | 描述           | 默认值 |
| ------ | ----------- | ------ |
| dfs.datanode.failed.volumes.tolerated | DataNode 停止提供服务前允许失败的卷数。默认情况下，必须至少有一个有效卷。 | 0 |

### 使用 Balancer 进行容量均衡

HDFS 集群可能出现 DataNode 节点间磁盘利用率不平衡的情况，例如集群中添加新 DataNode 的场景。如果 HDFS 出现数据不平衡的状况，则可能导致个别 DataNode 压力过大。

您可以使用 Balancer 操作进行容量均衡。

> **说明**：执行 Balancer 操作时会占用 DataNode 的网络带宽资源，请根据业务需求在业务空闲时期执行 Balancer 任务。

进入任意 hdfs 容器

**可选**：执行以下命令，修改 Balancer 的最大带宽。

```shell
hdfs dfsadmin -setBalancerBandwidth <bandwidth in bytes per second>
```

> **说明**：示例中的 <bandwidth in bytes per second> 为设置的最大带宽，例如，如果需要设置带宽控制为 20 MB/s，对应值为 20971520，则完整代码示例为 hdfs dfsadmin -setBalancerBandwidth 20971520。如果集群负载较高，可以改为 209715200（200 MB/s）；如果集群空闲，可以改为 1073741824（1 GB/s）。

执行以下命令，启动 Balancer。

```shell
/opt/hadoop/sbin/start-balancer.sh -threshold 10
```

执行以下命令，查看 Balancer 运行情况。
```shell
tail -f /opt/hadoop/logs/hadoop-hdfs-balancer-xxx.log
```

当提示信息包含 Successfully 字样时，表示执行成功。

## 管理 Hadoop 回收站

Hadoop 回收站是 Hadoop 文件系统的重要功能，可以恢复误删除的文件和目录。以下为您介绍 Hadoop 回收站的使用方法。

回收站是 Hadoop Shell 或部分应用（Hive 等）对 Hadoop FileSystem API 在客户端的封装，当客户端配置或者服务端配置打开回收站功能后，Hadoop Shell 会调用 FileSystem 的 rename 操作，把待删除的文件或者目录移动到 `/user/<username>/.Trash/Current` 目录中，否则会调用 FileSystem 的 delete 操作。

以 hadoop rm 命令为例，Hadoop 回收站流程图如下所示。

<img src='./images/05-best-practices-1.png'>

### 开启回收站

如流程图所示，只需在 KDP 的 HDFS 应用配置 coreSite 节点内查看 `fs.trash.interval` 参数，如果参数大于 0，就会开启回收站，执行 `-rm` 时，都会放置到回收站目录中。

### 关闭回收站

一旦关闭回收站后，执行 rm 便无法再次找回，通常不建议关闭，如果需要关闭可以修改 `fs.trash.interval` 为 0（HDFS 需要重启 NameNode 组件）。

### 访问回收站

默认回收站的目录为 `/user/<username>/.Trash/Current`，如果要访问对应到 HDFS 的回收站目录，可以加上对应前缀，例如 `hdfs://default/user/<username>/.Trash/Current`。

### 清理回收站目录

通常默认 1440 分钟，即放入 1 天后会自动清理。您可以通过参数 `fs.trash.interval` 修改检查点被删除的分钟数。

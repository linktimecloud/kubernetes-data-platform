# HDFS 组件使用

## 连接方式

### 进入 hdfs 容器

hdfs pod 有以下三种：

- hdfs-namenode-x
- hdfs-journalnode-x
- hdfs-datanode-x

上面的 `x` 代表序号，从 0 开始。

执行 Kubectl 命令进入容器，以进入 namespace `default` 中的 `hdfs-namenode-0` 为例

```shell
kubectl exec -it hdfs-namenode-0 -n default -- bash
```

然后可以执行 `hdfs` 命令

### 其他应用或程序访问 HDFS

其他应用访问 HDFS 需要有 `core-site.xml` 和 `hdfs-site.xml` 两个配置文件，可以从 configmap `hdfs-config` 中获得。详细可参考 HDFS 开发指南。

## 基础使用

### 在终端执行 hdfs 命令

参照上面方法进入任意 hdfs 容器。如果集群开启了 Kerberos，需要先执行

```shell
kinit -kt /etc/security/keytabs/hadoop.keytab hadoop/hadoop
```

然后可以进行 hdfs 命令操作，例如

```shell
hdfs dfs -ls /
hdfs dfs -put /本地一个文件 /hdfs路径
hdfs dfs -get /hdfs路径 /本地路径
```

## 手动恢复 Standby NameNode

在某些情况下，您需要手动恢复 Standby NameNode，例如某台 NameNode 数据目录被误删、NameNode editslog 产生了大量堆积，Active NameNode 状态健康并且已经手动完成 checkpoint 等场景。以下介绍如何手动恢复 Standby NameNode。

### 操作步骤

通过 WebUI 查看 NameNode 状态，确认 standby 状态的 Namenode。

进入需要恢复的 Namenode 容器。以 namespace `default` 下的 `hdfs-namenode-1` 为例：

```shell
kubectl exec -it hdfs-namenode-1 -n default -- bash
```

如果集群开启了 Kerberos，需要先执行

```shell
kinit -kt /etc/security/keytabs/hadoop.keytab hadoop/hadoop
```

执行以下命令，格式化 Standby NameNode。

```shell
hdfs --daemon stop namenode
hdfs namenode -bootstrapStandby
# 确认信息无误后，输入Y
```

等待容器重启。

## 手动进行 NameNode checkpoint

您可以通过手动进行 checkpoint 来保存 NameNode 的 Namespace 状态，并避免 NameNode 重启时间过长的问题。以下介绍如何手动进行 NameNode checkpoint。

### 操作步骤

进入任意一个的 Namenode 容器。以 namespace `default` 下的 `hdfs-namenode-0` 为例：

```shell
kubectl exec -it hdfs-namenode-0 -n default -- bash
```

如果集群开启了 Kerberos，需要先执行

```shell
kinit -kt /etc/security/keytabs/hadoop.keytab hadoop/hadoop
```

执行以下命令，进入 safemode 状态。

```shell
hdfs dfsadmin -safemode enter
```

> **重要**：NameNode checkpoint（saveNamespace）需要在 safemode 状态进行。一般在 safemode 状态下，DfsClient 会自动重试，请尽量避免在业务高峰期操作。

执行以下命令，进行 NameNode checkpoint（saveNamespace）。
建议您执行两次，可加速 edits 清理。

```shell
hdfs dfsadmin -saveNamespace
hdfs dfsadmin -saveNamespace
```

执行以下命令，退出 safemode 状态。

```shell
hdfs dfsadmin -safemode leave
```

# HDFS Component Usage

## Connection Methods

### Entering the HDFS Container

There are three types of HDFS pods:

- hdfs-namenode-x
- hdfs-journalnode-x
- hdfs-datanode-x

The `x` above represents the sequence number, starting from 0.

To enter the container, execute the Kubectl command. For example, to enter `hdfs-namenode-0` in the `default` namespace:


```shell
kubectl exec -it hdfs-namenode-0 -n default -- bash
```

Then you can execute `HDFS` commands.

### Accessing HDFS from Other Applications or Programs

Other applications need the `core-site.xml` and `hdfs-site.xml` configuration files to access HDFS, which can be obtained from the configmap `hdfs-config`. For more details, refer to the HDFS Developer Guide.

## Basic Usage

### Execute HDFS commands in the terminal.

Use the method mentioned above to enter any HDFS container. If the cluster has Kerberos enabled, execute:

```shell
kinit -kt /etc/security/keytabs/hadoop.keytab hadoop/hadoop
```

Then you can perform HDFS command operations, for example:

```shell
hdfs dfs -ls /
hdfs dfs -put /local/file /hdfs/path
hdfs dfs -get /hdfs/path /local/path
```

## Manually Recovering Standby NameNode

In some cases, you need to manually recover the Standby NameNode, such as when the NameNode data directory is mistakenly deleted, the NameNode editslog has a large amount of accumulation, the Active NameNode status is healthy and has manually completed the checkpoint, etc. Below is how to manually recover the Standby NameNode.

### Operation Steps

Check the NameNode status through the WebUI to confirm the Standby Namenode.

Enter the Namenode container that needs to be recovered. For example, `hdfs-namenode-1` in the `default` namespace:


```shell
kubectl exec -it hdfs-namenode-1 -n default -- bash
```

If the cluster has Kerberos enabled, first execute:

```shell
kinit -kt /etc/security/keytabs/hadoop.keytab hadoop/hadoop
```

Execute the following commands to format the Standby NameNode.

```shell
hdfs --daemon stop namenode
hdfs namenode -bootstrapStandby
# Confirm the information is correct and enter Y
```

Wait for the container to restart.

## Manually Performing NameNode Checkpoint

You can manually perform a checkpoint to save the NameNode's Namespace state and avoid the issue of NameNode restart taking too long. Below is how to manually perform a NameNode checkpoint.

### Operation Steps

Enter any Namenode container. For example, `hdfs-namenode-0` in the `default` namespace:

```shell
kubectl exec -it hdfs-namenode-0 -n default -- bash
```

If the cluster has Kerberos enabled, first execute:

```shell
kinit -kt /etc/security/keytabs/hadoop.keytab hadoop/hadoop
```

Execute the following command to enter safemode.

```shell
hdfs dfsadmin -safemode enter
```

> **Important**：NameNode checkpoint (saveNamespace) must be performed in safemode. Generally, in safemode, DfsClient will automatically retry, so try to avoid operations during peak business hours.

Execute the following command to perform NameNode checkpoint (saveNamespace). It is recommended to perform it twice to speed up edits cleanup.

```shell
hdfs dfsadmin -saveNamespace
hdfs dfsadmin -saveNamespace
```

Execute the following command to exit safemode.

```shell
hdfs dfsadmin -safemode leave
```

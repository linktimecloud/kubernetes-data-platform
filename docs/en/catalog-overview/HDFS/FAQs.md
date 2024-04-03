# HDFS FAQs

## DataNode Xceiver Number Limit Exception

### Specific Error:

```log
java.io.IOException: Xceiver count xxxx exceeds the limit of concurrent xcievers: xxxx
```

### Root Cause 

The `dfs.datanode.max.transfer.threads` parameter is used to set the thread pool size for DataNode to handle read and write data streams, with a default value of 4096. If this parameter is set too low, it will cause the Xceiver number limit exception on DataNode.

### Solutions:

In the KDP HDFS application configuration, under the hdfsSite node, check the parameter `dfs.datanode.max.transfer.threads` and appropriately increase its value, generally it is recommended to double it, for example, 8192 、16384.

## Writing Files Indicate DataXceiver Premature EOF from InputStream

### Specific Error:

```log
DataXceiver error processing WRITE_BLOCK operation src: /10.*.*.*:35692 dst: /10.*.*.*:50010 java.io.IOException: Premature EOF from inputStream
```

### Root Cause

Usually, to continuously write new data to HDFS, jobs will open a large number of HDFS file write streams (Streams). However, the number of files that HDFS allows to open simultaneously is limited, constrained by the DataNode parameters, and exceeding the limit will result in the DataXceiver Premature EOF from InputStream exception.

### Solutions

Check the DataNode logs, which generally will have the following error:

```log
java.io.IOException: Xceiver count 4097 exceeds the limit of concurrent xcievers: 4096
at org.apache.hadoop.hdfs.server.datanode.DataXceiverServer.run(DataXceiverServer.java:150)
```

If the error exists, in the KDP HDFS application configuration, under the hdfsSite node, check the parameter ·dfs.datanode.max.transfer.threads· and appropriately increase its value, generally it is recommended to double it, for example, 8192, 16384.

## Writing Files Indicate Inability to Meet Minimum Write Replica Requirements

### Specific Error:

The error message is shown as follows. In which, [X] is the current number of DataNodes running, and [Y] is the number of DataNodes excluded from this operation.

```log
org.apache.hadoop.ipc.RemoteException(java.io.IOException): File /foo/file1 could only be written to 0 of the 1 minReplication nodes,there are 【X】 datanode(s) running and 【Y】 node(s) are excluded in this operation.
```

### Root Cause

This issue indicates that due to the current cluster state, HDFS is unable to write the file to the specified path because the minimum number of replicas for the file cannot be met.

### Solutions

If [Y] is not 0, it means some DataNode nodes are excluded by the HDFS client, and it is necessary to check whether the load on the DataNode nodes is too high. When the DataNode is overloaded or its capacity is too small, writing multiple files at the same time can cause the DataNode to be unable to handle the block allocation requests from the NameNode, and it is necessary to expand the DataNode.

If [X] is not 0, and [X] > [Y], you can check the following aspects.

If there are few DataNode nodes (fewer than 10) or their capacity is full, and there are many jobs in the cluster that write a large number of small files, it may cause the NameNode to be unable to find suitable DataNode nodes for writing. This situation is common in scenarios where Flink Checkpoint writes to HDFS; Hive or Spark dynamic partition writing jobs require a large number of partitions.

To solve this problem, you can increase the number or capacity of DataNodes in the cluster. It is recommended to expand the number of DataNodes, which can quickly solve this problem in general, and it is more convenient to scale down later, thus better meeting the needs for writing a large number of small files.

## Writing to HDFS Results in Exception Unable to Close File

### Specific Error:

```log
java.io.IOException: Unable to close file because the last block xxx:xxx does not have enough number of replicas.
```

### Root Cause
This is generally caused by the DataNode having too much write load, and the data block cannot be reported in time.

### Solutions

It is recommended to troubleshoot and resolve as follows:

Check HDFS Configuration

In the KDP HDFS application configuration, check the ·dfs.client.block.write.locateFollowingBlock.retries· (the number of attempts to close after writing a block) parameter in the hdfsSite node. The default is 5 times (30 seconds), it is recommended to set it to 8 times (2 minutes), and clusters with high load can continue to increase it as necessary.

> **Note**：Increasing the `dfs.client.block.write.locateFollowingBlock.retries` parameter value will extend the file close wait time when the node is busy, and normal writing is not affected.

Confirm whether there are only a few DataNode nodes and a large number of task nodes in the cluster. If a large number of concurrent job submissions occur, there will be a large number of JAR files that need to be uploaded, which may cause a sudden increase in pressure on DataNode, and you can continue to increase the `dfs.client.block.write.locateFollowingBlock.retries` parameter value or increase the number of DataNodes.

> **Note**：Increasing the `dfs.client.block.write.locateFollowingBlock.retries` parameter value will extend the file close wait time when the node is busy, and normal writing is not affected.

Confirm whether there are a large number of jobs in the cluster that consume DataNode resources. For example, Flink Checkpoint will create and delete a large number of small files, causing the DataNode to be overloaded. In such scenarios, you can run Flink on a separate cluster, and Checkpoint will use a separate HDFS, or use OSS/OSS-HDFS Connector to optimize Checkpoint.

## NameNode or JournalNode's editlogs Directory Occupies a Large Amount of Disk Space

### Root Cause

HDFS relies on FsImage Checkpoint to merge editlogs. When the FsImage Checkpoint encounters an exception, it will cause the editlogs to not merge. The usual exceptions are caused by the FsImage directory being full or disk exceptions, and the NameNode restart time will also become very long. After the NameNode FsImage Checkpoint fails, the FsImage directory will not be used again by default, and you need to set the FsImage directory to automatically recover.

### Solutions

Enter any HDFS container and manually enable the FsImage directory auto-recovery option.

```shell
hdfs dfsadmin -restoreFailedStorage true
```

> **Note**：Manually enabling the FsImage directory auto-recovery option will become invalid after a restart.

After successful activation, the NameNode will attempt to recover the FsImage directory first during subsequent automatic FsImage Checkpoint.

You can also enable the FsImage directory auto-recovery function by default.

In the KDP HDFS application configuration, under the hdfsSite node, add a custom configuration with the parameter `dfs.namenode.name.dir.restore` set to `true`, and the FsImage directory auto-recovery function will automatically turn on after the next NameNode restart.


## NameNode Cannot Exit Safemode After Starting

The following are the reasons and solutions for NameNode being unable to exit safemode state after starting.

### Specific Error:

The NameNode log or HDFS WebUI displays the following error message, which will not be able to exit safemode, causing the HDFS service to be basically unusable.

```log
Safemode is ON.The reported blocks xxx needs addition ablocks to reach the threshold 0.9990 of total blocks yyy
```

### Root Cause

This issue is usually caused by the data blocks reported by DataNode not reaching the total volume threshold ratio (default is 0.999f), preventing NameNode from exiting safemode. First, confirm that all DataNodes have started normally. If there are no issues with the DataNode processes, the problem may lie in the following two aspects:

1. Improper maintenance operations leading to data block loss, unable to reach the threshold ratio. If such a situation occurs, NameNode will not automatically exit safemode.
2. The DataNode block reporting time is too long, which often occurs when a large number of DataNodes restart or NameNode restarts (full restart, not a normal HA switch) and a large number of HDFS service processes abnormally restart. In such cases, DataNode needs to trigger a full block report, and NameNode will automatically exit safemode after receiving data blocks that reach the threshold. The duration of the entire recovery process depends on the number of data blocks.

### Solutions

Option 1: Manually exit safemode through the hdfs command.

```shell
hdfs dfsadmin -safemode leave
```

Option 2: Appropriately lower the threshold ratio by modifying the following configuration item, and add it to the hdfsSite node in the KDP HDFS application configuration

```yaml
"dfs.namenode.safemode.threshold-pct": "0.9f"
```

> **Note**：The above parameter value of 0.9f is just an example. In actual use, please adjust the value of the `dfs.namenode.safemode.threshold-pct` parameter according to your specific situation.

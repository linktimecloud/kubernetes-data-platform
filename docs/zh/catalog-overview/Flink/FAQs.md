# Flink 常见问题

## FlinkDeployment 可配置的参数有哪些

可以参考 [FlinkDeployment](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.3/docs/custom-resource/reference/)

## FlinkDeployment 中的 flinkConfiguration 有哪些参数

可以参考 [FlinkConfiguration](https://nightlies.apache.org/flink/flink-docs-release-1.14/docs/deployment/config/)

## Jobmanager与Taskmanager心跳超时，导致Flink作业异常

1. 分析网络是否发生闪断，此时集群负载是否很高
2. 分析是否在频繁Full GC，若频繁Full GC, 用户可以排查代码，确认是否有内存泄漏。
3. 调整`taskManager.resource.memory`参数，增加taskManager资源。

## OutOfMemoryError: Java heap space

The exception usually indicates that the JVM heap is too small.

1. 调整`taskManager.resource.memory`参数，增加Taskmanager所占的资源。
2. 优化代码，减少内存占用。
3. 或者配置`flinkConfiguration` 中的 `taskmanager.memory.task.heap.size` [参考](https://nightlies.apache.org/flink/flink-docs-release-1.10/ops/memory/mem_setup.html#task-operator-heap-memory)

## 增加slot数量

Could not allocate the required slot within slot request timeout

1. 调整`taskmanager.numberOfTaskSlots`参数，增加slot数量。
2. 调整任务的并行度, 过高的并行度会导致slot不足。

## IOException: Insufficient number of network buffers

该报错通常表示配置的网络内存大小不够大，可以尝试通过调整`flinkConfiguration`中的配置来增加网络内存：

1. taskmanager.memory.network.min
2. taskmanager.memory.network.max
3. taskmanager.memory.network.fraction
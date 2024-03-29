### 1. 介绍
Flink Kubernetes Operator 的核心用户面向 API 是 FlinkDeployment 和 FlinkSessionJob 自定义资源（Custom Resources）。

自定义资源（Custom Resources）是 Kubernetes API 的扩展，定义了新的对象类型。在我们的案例中，FlinkDeployment CR 定义了 Flink 应用程序和会话集群部署。FlinkSessionJob CR 定义了会话集群上的会话作业，每个会话集群可以运行多个 FlinkSessionJob。

应用程序 `flink-session-cluster` 基于 FlinkDeployment CR 创建会话集群。用户可以通过 Flink Web UI 将 Flink 作业提交到会话集群。


### 2. 快速开始
我们将演示如何通过Flink Web UI将 Flink 作业提交到会话集群。

前提条件：

1. 会话集群Ingress可以访问。（例如Flink Web UI：`http://flink-session-cluster-ingress.yourdomain.com`）

#### 获取 Flink 作业 Jar 文件
1. 您可以从[这里](https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.17.1/flink-examples-streaming_2.12-1.17.1-WordCount.jar)下载 Flink 作业 jar 文件，文件名为 `flink-examples-streaming_2.12-1.17.1-WordCount`。

#### 将 Flink 作业提交到会话集群
1. 打开 Flink Web UI（（例如Flink Web UI：`http://flink-session-cluster-ingress.yourdomain.com`）
2. 点击 `Submit New Job` -> `Add New`，选择上一步下载的 jar 文件上传, 将 Flink 作业提交到会话集群。

稍后您可以在 Flink Web UI 中看到 Flink 作业正在运行。

### 3. FQA

#### FlinkDeployment 可配置的参数有哪些
可以参考 [FlinkDeployment](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.6/docs/custom-resource/reference/)

#### FlinkDeployment 中的 flinkConfiguration 有哪些参数
可以参考 [FlinkConfiguration](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/deployment/config/)


#### Jobmanager与Taskmanager心跳超时，导致Flink作业异常
1. 分析网络是否发生闪断，此时集群负载是否很高
2. 分析是否在频繁Full GC，若频繁Full GC, 用户可以排查代码，确认是否有内存泄漏。
3. 调整`taskManager.resource.memory`参数，增加taskManager资源。

#### OutOfMemoryError: Java heap space
The exception usually indicates that the JVM heap is too small.

1. 调整`taskManager.resource.memory`参数，增加Taskmanager所占的资源。
2. 优化代码，减少内存占用。
3. 或者配置`flinkConfiguration` 中的 `taskmanager.memory.task.heap.size` [参考](https://nightlies.apache.org/flink/flink-docs-release-1.17/ops/memory/mem_setup.html#task-operator-heap-memory)


#### 增加slot数量
Could not allocate the required slot within slot request timeout

1. 调整`taskmanager.numberOfTaskSlots`参数，增加slot数量。
2. 调整任务的并行度, 过高的并行度会导致slot不足。

#### IOException: Insufficient number of network buffers 
该报错通常表示配置的网络内存大小不够大，可以尝试通过调整`flinkConfiguration`中的配置来增加网络内存：

1. taskmanager.memory.network.min
2. taskmanager.memory.network.max
3. taskmanager.memory.network.fraction


### 4. 概念
#### 4.1 Job Manager
Job Manager 负责接受客户端提交的作业，调度它们执行，并监控它们的进度。Job Manager 还维护作业的进度和状态的集群范围视图。

#### 4.2 Task Manager
Task Manager 负责执行实际的数据处理任务。每个 Task Manager 负责执行一个或多个任务，并与 Job Manager 通信以接收任务并报告其进度。

#### 4.3 Job & Task
Apache Flink 是一个分布式处理引擎，用于执行大数据处理任务。在 Flink 中，作业（Job）指的是在 Flink 集群上执行的用户定义的数据处理程序。Flink 作业通常由多个并行执行的任务(Task)组成，这些任务在集群中的不同节点上并行执行。

Task 是 Flink 作业中的最小工作单元，负责处理输入数据的子集。Flink 使用并行数据处理模型，其中输入数据被分区为多个数据流，并且每个流由一个或多个并行任务处理。

Job 通常由几个相互连接的Task组成，这些Task对数据执行不同的操作，例如过滤、映射、聚合、连接或窗口。Flink 提供了高级 API 和一组运算符，开发人员可以使用它们来实现这些操作并定义作业逻辑。

一旦将 Flink Job 提交到 Flink 集群，它将被分成一系列Task，这些Task分布在集群中的节点上。Flink 运行时负责管理任务的执行，调度它们执行，并处理它们之间的数据交换。Flink 运行时还提供容错机制，以确保Job可以从故障中恢复并继续处理，即使某些任务或节点失败。

#### 4.4 Checkpoint
Checkpoint 是 Flink 作业状态的一致快照。Checkpoint 会定期创建以允许从故障中恢复。Checkpoint 可以是增量的，并且只存储自上次 Checkpoint 以来的更改。

#### 4.5 Savepoint
Savepoint 是 Flink 作业状态的一致快照。Savepoint 可以手动创建，也可以作为手动或自动故障转移的一部分创建。Savepoint 可以是增量的，并且只存储自上次 Checkpoint 以来的更改。

#### 4.6 FlinkDeployment
FlinkDeployment 是 Kubernetes 自定义资源，用于定义 Flink 集群部署。它用于在 Kubernetes 上部署 Flink 集群。

#### 4.7 FlinkSessionJob
FlinkSessionJob 是 Kubernetes 自定义资源，用于定义 Flink 会话集群上的会话作业。它用于将 Flink 作业提交到 Flink 会话集群。



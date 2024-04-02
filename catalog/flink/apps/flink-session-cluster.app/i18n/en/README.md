

### 1. Introduction
The core user facing API of the Flink Kubernetes Operator is the FlinkDeployment and FlinkSessionJob Custom Resources (CR).

Custom Resources are extensions of the Kubernetes API and define new object types. In our case the FlinkDeployment CR defines Flink Application and Session cluster deployments. The FlinkSessionJob CR defines the session job on the Session cluster and each Session cluster can run multiple FlinkSessionJob.

The `flink-session-cluster` application is based on the FlinkDeployment CR to create a session cluster. Users can submit Flink jobs to the session cluster through the Flink WebUI.


### 2. Quick Start

We will demonstrate how to submit a Flink job to the session cluster.
Prerequisites:

1. the endpoint of the session cluster is exposed to the outside of the cluster.(eg: Flink WebUI: `http://flink-session-cluster-ingress.yourdomain.com`)

#### Flink Job Jar File
you can dowload the Flink job jar file from [here](https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.17.1/flink-examples-streaming_2.12-1.17.1-WordCount.jar), file name is `flink-examples-streaming_2.12-1.17.1-WordCount`.

#### Submit Flink Job to the Session Cluster  
open the Flink WebUI, and submit a Flink job to the session cluster.

1. Open the Flink WebUI (eg: Flink WebUI: `http://flink-session-cluster-ingress.yourdomain.com`)
2. Click `Submit New Job` -> `Add New`, select the jar file you downloaded in the previous step, and submit the Flink job to the session cluster.

You can see the Flink job running in the Flink WebUI later.

### 3. FQA

#### What are the configuration parameters of FlinkDeployment
You can refer to [FlinkDeployment](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.6/docs/custom-resource/reference/)

#### What are the parameters of `flinkConfiguration` in `FlinkDeployment`
You can refer to [FlinkConfiguration](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/deployment/config/)

#### Jobmanager and Taskmanager heartbeat timeouts leading to Flink job abnormality
1. Verify if there is a network flash break, and whether the cluster load is high at this time.
2. Verify whether frequent Full GC occurs. If so, users can troubleshoot the code to confirm whether there is a memory leak.
3. Adjust the `taskManager.resource.memory` parameter to increase the Taskmanager resources.

#### OutOfMemoryError: Java heap space
1. Adjust `taskManager.resource.memory` parameter, increase the resources occupied by Taskmanager.
2. Optimize the code to reduce memory usage.
3. Or configure `taskmanager.memory.task.heap.size` in `flinkConfiguration` [reference](https://nightlies.apache.org/flink/flink-docs-release-1.17/ops/memory/mem_setup.html#task-operator-heap-memory)

#### How to increase the number of slots
1. Adjust the `taskmanager.numberOfTaskSlots` parameter to increase the number of slots.
2. Adjust the parallelism of the task, too high parallelism will cause insufficient slots.

#### IOException: Insufficient number of network buffers 
The exception usually indicates that the size of the configured network memory is not big enough. You can try to increase the network memory by adjusting the following options:

1. taskmanager.memory.network.min
2. taskmanager.memory.network.max
3. taskmanager.memory.network.fraction


### 4. Concepts
#### 4.1 Job Manager
The Job Manager is responsible for accepting jobs submitted by clients, scheduling them for execution, and monitoring their progress. The Job Manager also maintains a cluster-wide view of the job's progress and status.

#### 4.2 Task Manager
The Task Manager is responsible for executing the actual data processing tasks. Each Task Manager is responsible for executing one or more tasks, and it communicates with the Job Manager to receive tasks and report their progress.

#### 4.3 Job & Task
Apache Flink is a distributed processing engine designed to perform big data processing tasks. In Flink, a job refers to a user-defined data processing program that is executed on a Flink cluster. A Flink job typically consists of multiple tasks that are executed in parallel on different nodes in the cluster.

A Flink task is the smallest unit of work in a Flink job, and it is responsible for processing a subset of the input data. Flink uses a parallel data processing model, where the input data is partitioned into multiple data streams, and each stream is processed by one or more tasks in parallel.

A Flink job is typically composed of several interconnected tasks that perform different operations on the data, such as filtering, mapping, aggregating, joining, or windowing. Flink provides a high-level API and a set of operators that developers can use to implement these operations and define their job logic.

Once a Flink job is submitted to the Flink cluster, it is split into a series of tasks that are distributed across the nodes in the cluster. The Flink runtime manages the execution of the tasks, schedules them for execution, and handles data exchange between them. The Flink runtime also provides fault tolerance mechanisms to ensure that the job can recover from failures and continue processing even if some tasks or nodes fail.
#### 4.4 Checkpoint
A Checkpoint is a consistent snapshot of the state of a Flink job. Checkpoints are created periodically to allow recovery from failures. Checkpoints can be incremental, and only store changes since the previous checkpoint.

#### 4.5 Savepoint
A Savepoint is a consistent snapshot of the state of a Flink job. Savepoints are created manually or as part of a manual or automatic failover. Savepoints can be incremental, and only store changes since the previous checkpoint.

#### 4.6 FlinkDeployment
A FlinkDeployment is a Kubernetes custom resource that defines a Flink cluster deployment. It is used to deploy a Flink cluster on Kubernetes.

#### 4.7 FlinkSessionJob
A FlinkSessionJob is a Kubernetes custom resource that defines a Flink job on a Flink session cluster. It is used to submit a Flink job to a Flink session cluster.

# Flink FAQs

## What configurable parameters are there for FlinkDeployment?

You can refer to the [FlinkDeployment](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.3/docs/custom-resource/reference/)

## What are the parameters in the flinkConfiguration of FlinkDeployment?

Please refer to the [FlinkConfiguration](https://nightlies.apache.org/flink/flink-docs-release-1.14/docs/deployment/config/)

## Jobmanager and Taskmanager heartbeat timeout, causing Flink job exceptions.

1. Analyze if there are any network flickers, and check if the cluster load is high at that time.
2. Determine if there is frequent Full GC; if Full GC is frequent, users can investigate the code to confirm if there is a memory leak.
3. Adjust the `taskManager.resource.memory` parameter to increase the resources for the Taskmanager.

## OutOfMemoryError: Java heap space

The exception usually indicates that the JVM heap is too small.

1. Adjust the `taskManager.resource.memory` parameter to increase the resources occupied by the Taskmanager.
2. Optimize the code to reduce memory usage.
3. Or configure the `taskmanager.memory.task.heap.size` in the `flinkConfiguration` for reference. [Refer](https://nightlies.apache.org/flink/flink-docs-release-1.10/ops/memory/mem_setup.html#task-operator-heap-memory)

## Increase the number of slots.

Could not allocate the required slot within slot request timeout

1. Adjust the `taskmanager.numberOfTaskSlots` parameter to increase the number of slots.
2. Adjust the parallelism of the job; excessive parallelism can lead to a shortage of slots.

## IOException: Insufficient number of network buffers

This error typically indicates that the configured network memory size is not large enough. You can try to increase the network memory by adjusting the configurations in the `flinkConfiguration`:

1. taskmanager.memory.network.min
2. taskmanager.memory.network.max
3. taskmanager.memory.network.fraction
# Kafka Best Practices

## Publisher Best Practices

### Key and Value

Key：The identifier for a message.
Value：The content of the message.

To facilitate tracking, set a unique Key for each message. You can track a message by its Key, print send logs and consume logs to understand the transmission and consumption of the message.

If there is a high volume of message sending, it is recommended not to set a Key and use the sticky partitioning strategy. For details on the sticky partitioning strategy, please refer to the section on sticky partitioning strategy.

### Retry on Failure

In a distributed environment, occasional failures due to network issues are common. The reasons for such failures may be that the message has been sent successfully but the ACK has failed, or the message has not been sent at all.


You can set the following retry parameters based on business needs：

retries：The number of retries when a message sending fails.

retry.backoff.ms，The retry interval when a message sending fails. It is recommended to set it to 1000, in milliseconds.

### Asynchronous Sending

The sending interface is asynchronous. If you want to receive the result of the sending, you can call metadataFuture.get(timeout, TimeUnit.MILLISECONDS).

### Thread Safety

The Producer is thread-safe and can send messages to any Topic. Typically, one application corresponds to one Producer.

### Acks

The explanation of Acks is as follows：

acks=0：No server response is required, high performance, high risk of data loss.

acks=1：The server's primary node writes successfully and then returns the response, medium performance, medium risk of data loss, data loss may occur if the primary node goes down.

acks=all：The server's primary node writes successfully and the backup node synchronizes successfully before returning the response, poor performance, data is safer, data loss will only occur if both the primary and backup nodes go down.

To improve sending performance, it is recommended to set acks=1.

### Improving Sending Performance (Reducing Fragmented Sending Requests)

In general, a Kafka Topic will have multiple partitions. When the Kafka Producer client sends messages to the server, it needs to first confirm which partition of which Topic to send to. When we send multiple messages to the same partition, the Producer client packs related messages into a Batch and sends them to the server in batches. There is additional overhead when the Producer client handles Batches. Under normal circumstances, small Batches will cause the Producer client to generate a large number of requests, causing requests to queue up on the client and server, and increasing the CPU usage of related machines, thereby overall increasing the latency of message sending and consumption. An appropriate Batch size can reduce the number of requests sent by the client to the server when sending messages, thereby improving the throughput and latency of message sending overall.

The Batch mechanism of the Kafka Producer is mainly controlled by two parameters：

batch.size : The amount of message cache (the sum of the byte count of message content, not the number of messages) sent to each partition (Partition). When the set value is reached, it will trigger a network request, and then the Producer client sends messages to the server in batches. If batch.size is set too small, it may affect the sending performance and stability. It is recommended to keep the default value of 16384. Unit: bytes.

linger.ms : The maximum time for each message to stay in the cache. If this time is exceeded, the Producer client will ignore the limit of batch.size and immediately send the message to the server. It is recommended to set linger.ms between 100 and 1000 according to the business scenario. Unit: milliseconds.

Therefore, when the Kafka Producer client sends messages to the server in batches is jointly determined by batch.size and linger.ms. You can adjust according to specific business needs. To improve sending performance and ensure service stability, it is recommended to set batch.size=16384 and linger.ms=1000.

### Sticky Partitioning Strategy

Only messages sent to the same partition will be placed in the same Batch, so one factor that determines how a Batch is formed is the partitioning strategy set on the Kafka Producer side. Kafka Producer allows you to choose a partition that suits your business by setting the implementation class of the Partitioner. When a message has a specified Key, the default strategy of the Kafka Producer is to hash the Key of the message and then select the partition based on the hash result, ensuring that messages with the same Key are sent to the same partition.

When a message does not have a specified Key, the default strategy before Kafka version 2.4 was to cycle through all partitions of the topic and send messages to each partition in a round-robin manner. However, this default strategy has a poor Batch effect, and in actual use, it may generate a large number of small Batches, thereby increasing the actual latency. In view of the low partitioning efficiency problem for messages without Keys in this default strategy, Kafka introduced the sticky partitioning strategy (Sticky Partitioning Strategy) in version 2.4. Using the Kafka provided by KDP will default to enabling the sticky partitioning strategy.

The main solution of the sticky partitioning strategy is to address the issue of messages without Keys being scattered to different partitions, causing small Batch problems. The main strategy is that if a Batch of a partition is completed, it will randomly select another partition, and then subsequent messages will use that partition. This strategy, viewed in the short term, will send messages to the same partition, but over the entire running time, messages can still be evenly published to all partitions. This can avoid message partition skew and also reduce latency, improving the overall performance of the service.

### OOM (Out of Memory)

In line with Kafka's Batch design philosophy, Kafka caches messages and sends them in batches. If too much cache is used, it may cause OOM (Out of Memory).

buffer.memory : The size of the send memory pool. If the memory pool is set too small, it may lead to a long time to allocate memory, thereby affecting the sending performance and even causing a send timeout. It is recommended that buffer.memory be greater than or equal to batch.size * number of partitions * 2. Unit: bytes.

The default value of buffer.memory is 32 MB, which can ensure sufficient performance for a single Producer.

Important: 
If you start multiple Producers in the same JVM, each Producer may occupy 32 MB of cache space, which may then trigger OOM.

In production, there is generally no need to start multiple Producers; if there are special circumstances that require it, you need to consider the size of buffer.memory to avoid triggering OOM.

### Partition Order

Within a single partition (Partition), messages are stored in the order they are sent and are basically ordered.

By default, Kafka does not guarantee absolute order within a single partition in order to improve availability, and a small amount of message disorder may occur during upgrades or outages (when a partition goes down, messages are Failover to other partitions).

If the business requires strict order within a partition, please choose to use Local storage when creating a Topic.

## Consumer Best Practices

### Number of Partitions

The number of partitions mainly affects the number of consumers' concurrency.

For consumers within the same Group, a partition can only be consumed by one consumer at most. Therefore, the number of consumer instances should not exceed the number of partitions, otherwise, there will be consumer instances that are not assigned to any partition and are in a state of idling.

The default number of partitions in the console is 12, which can meet the needs of most scenarios. You can increase it according to the business usage volume. It is not recommended to have fewer than 12 partitions as it may affect the sending and receiving performance; it is also not recommended to exceed 100, as it may easily cause consumer端Rebalance.

### Consumer Offset Commit

Kafka consumers have two related parameters：

enable.auto.commit：Whether to use the automatic offset commit mechanism. The default value is `true`, which means the automatic commit mechanism is used by default.

auto.commit.interval.ms： 自The time interval for automatic offset commitment. The default value is 1000, i.e., 1 second.

The combination of these two parameters means that before each poll for data, the last committed offset will be checked. If the time since the last commit has exceeded the duration specified by the parameter auto.commit.interval.ms, the client will initiate an offset commit action.

Therefore, if you set enable.auto.commit to true, you need to ensure that the data polled from the last time has been consumed before each poll for data, otherwise, it may lead to offset jumping.

If you want to control the offset commitment yourself, please set enable.auto.commit to `false` and call the commit(offsets) function to control the offset commitment manually.

### Consumer Offset Reset

Consumer offset reset will occur in the following two situations：

When the server no longer has the previously committed offset (for example, when the client first comes online).


When pulling messages from an illegal offset (for example, starting from offset 11 when the maximum offset for a partition is 10).

The Java client can configure the reset strategy through auto.offset.reset, including three strategies:

latest：Start consuming from the maximum offset.

earliest：Start consuming from the minimum offset.

none：Do nothing, i.e., do not reset.

Note
It is recommended to set it to `latest` instead of `earliest` to avoid starting consumption from the beginning due to illegal offsets, thereby causing a large number of duplicates.

If you manage the offsets yourself, you can set it to `none`.

### Pulling Large Messages

The consumption process is initiated by the client to pull messages from the server. When pulling large messages, it is important to control the pulling speed and pay attention to modifying the configuration:

max.poll.records：The maximum number of messages obtained in each Poll. If a single message exceeds 1 MB, it is recommended to set it to 1.

fetch.max.bytes：Set it slightly larger than the size of a single message.

max.partition.fetch.bytes：Set it slightly larger than the size of a single message.

The core of pulling large messages is to pull them one by one.

### Message Duplication and Consumer Idempotence

The semantics of Kafka consumption is at least once, which means at least one delivery, ensuring that messages are not lost, but it cannot guarantee that messages are not duplicated. A small number of duplicate messages may occur in the event of network problems or client restarts. At this time, if the application consumer side is sensitive to message duplication (such as order transactions), message idempotence should be done.

For example, in database applications, common practices are：

When sending a message, pass in the key as the unique serial number ID.

When consuming a message, check whether the key has been consumed. If it has been consumed, ignore it; if it has not been consumed, consume it once.

If the application itself is not sensitive to a small number of message duplicates, then there is no need for such idempotent checks.

### Consumer Failure

Kafka consumes messages in order, partition by partition. If the consumer fails to execute the consumption logic after obtaining a message, for example, if the application server encounters dirty data, causing a message processing failure and waiting for manual intervention, there are the following two ways to handle it:

Keep trying to execute the consumption logic after failure. This approach may cause the consumption thread to be blocked on the current message, unable to move forward, causing message accumulation.

Kafka does not have a design for handling failed messages. In practice, it is common to print failed messages or store them in a service (for example, create a Topic specifically for placing failed messages), and then periodically check the situation of failed messages, analyze the reasons for failure, and handle them according to the situation.

### Consumer Latency

The consumption mechanism of Kafka is that the client actively pulls messages from the server for consumption. Therefore, if the client can consume in a timely manner, there will be no significant latency. If there is a significant latency, please first pay attention to whether there is accumulation and pay attention to increasing the consumption speed.

### Consumer Blockage and Accumulation

The most common problem on the consumer side is consumption accumulation, and the most common cause of accumulation is:

The consumption speed cannot keep up with the production speed. In this case, the consumption speed should be increased. For details, please refer to the section on increasing consumption speed.

The consumer side is blocked.

The consumer side takes the message and executes the consumption logic, usually performing some remote calls. If synchronization waits for the result at this time, it may cause continuous waiting, and the consumption process cannot move forward.

The consumer side should try its best to avoid blocking the consumption thread. If there is a situation where the call result is waiting, it is recommended to set a timeout for waiting, and handle it as a consumption failure after the timeout.

### Increasing Consumption Speed

There are the following two ways to increase consumption speed：

1.Increase the number of Consumer instances.

You can directly increase them within the process (you need to ensure that each instance corresponds to a thread, otherwise, it doesn't make much sense), or you can deploy multiple consumer instance processes; it should be noted that after the number of instances exceeds the number of partitions, the speed will no longer be improved, and there will be consumer instances that do not work.

2.Increase the consumption threads.

Increasing Consumer instances is essentially also a way to increase threads to improve speed, so the more important way to improve performance is to increase consumption threads. The most basic steps are as follows:

- Define a thread pool.
- Poll data.
- Submit data to the thread pool for concurrent processing. 
- After the concurrent results are returned successfully, poll data again for execution.

### Message Filtering

Kafka itself does not have the semantics of message filtering. In practice, the following two methods can be adopted:

If there are not many types of filtering, you can use multiple Topics to achieve the purpose of filtering.

If there are many types of filtering, it is best to filter on the client business level.

In practice, please choose according to the specific situation of the business, and you can also use the above two methods in combination.
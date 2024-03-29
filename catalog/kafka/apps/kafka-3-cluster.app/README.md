### 1. 应用说明

Kafka是一个分布式、高吞吐、可扩展的消息队列服务，广泛用于日志收集、流式数据处理、在线和离线分析等大数据领域，是大数据生态中不可或缺的部分。

### 2. 快速入门

#### 2.1. 资源准备

##### 2.1.1. **接入点获取**

KDP 大数据集群管理-集群信息-应用使用配置 kafka-3-cluster-kafka-context 获得访问地址、端口

##### 2.1.2. **Topic创建**

使用kafka manager或通过Kafka命令创建

#### 2.2. 使用实践

**java程序代码**

1. 安装Java依赖库

   在pom.xml中添加以下依赖。

```xml
   <dependency>
       <groupId>org.apache.kafka</groupId>
       <artifactId>kafka-clients</artifactId>
       <version>3.4.1</version>
   </dependency>
```

2. 创建Kafka配置文件kafka-cfg.properties

```properties
   ## 配置kafka接入点
   bootstrap.servers=【在2.1.1获得的kafka url】
   ## 配置Topic
   topic=【在2.1.2创建的topic】
   ## 配置Consumer Group，自定义带用户id的字符串
   group.id=【自定义消费组名称】
```

3. 工具类准备

```java
   import java.util.Properties;
   
   public class KafkaCfg {
       private static Properties properties;
       public static final String BOOTSTRAP_SERVERS = "bootstrap.servers";
       public static final String TOPIC = "topic";
       public static final String GROUP_ID = "group.id";
     
     
       public synchronized static Properties getKafkaProperties() {
           if (null != properties) {
               return properties;
           }
           // 获取配置文件kafka-cfg.properties
           Properties kafkaProperties = new Properties();
           try {
               kafkaProperties.load(KafkaCfg.class.getClassLoader().getResourceAsStream("kafka-cfg.properties"));
           } catch (Exception e) {
               // 配置加载失败，异常退出。
               e.printStackTrace();
           }
           properties = kafkaProperties;
           return kafkaProperties;
       }
   }
```

4. 生产消息实践

```java
   import org.apache.kafka.clients.producer.KafkaProducer;
   import org.apache.kafka.clients.producer.ProducerConfig;
   import org.apache.kafka.clients.producer.ProducerRecord;
   
   import java.util.Properties;
   
   public class KdpKafkaProducer {
   
       public static void main(String args[]) {
           //加载kafka-cfg.properties。
           Properties kafkaCfgProperties =  KafkaCfg.getKafkaProperties();
   
           Properties props = new Properties();
           //设置接入点，请通过控制台获取对应Topic的接入点。
           props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaCfgProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
   
           //kafka ack消息确认机制，1代表leader确认后返回，-1代表需要所有replicas确认才返回
           props.put("acks", "1");
           //Kafka消息的序列化方式。
           props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           //请求的最长等待时间。
           props.put(ProducerConfig.MAX_BLOCK_MS_CONFIG, 30 * 1000);
           //设置客户端内部重试次数。
           props.put(ProducerConfig.RETRIES_CONFIG, 5);
           //设置客户端内部重试间隔。
           props.put(ProducerConfig.RECONNECT_BACKOFF_MS_CONFIG, 3000);
           //构造Producer对象，该对象是线程安全的。
           KafkaProducer<String, String> producer = new KafkaProducer<>(props);
   
           //消息所属的Topic
           String topic = kafkaCfgProperties.getProperty(KafkaCfg.TOPIC);
           //消息key，可以为null
           String key = "message key";
           //消息的内容，这里只是个测试string，实际生产场景多将消息对象转换成json或是avro格式字符串。
           String value = "this is the message's value";
   
           for (int i = 0; i< 100 ; i++) {
               ProducerRecord<String, String> record = new ProducerRecord<>(topic,
                       key + i,
                      value + i);
               producer.send(record);
           }
          producer.flush();
       }
   }
```



参考自定义应用发布流程发布到KDP运行。



5. 消息消费实践

```java
   import org.apache.kafka.clients.consumer.ConsumerConfig;
   import org.apache.kafka.clients.consumer.ConsumerRecord;
   import org.apache.kafka.clients.consumer.ConsumerRecords;
   import org.apache.kafka.clients.consumer.KafkaConsumer;
   import org.apache.kafka.clients.producer.ProducerConfig;
   
   import java.util.ArrayList;
   import java.util.List;
   import java.util.Properties;
   
   public class KdpKafkaConsumer {
   
       public static void main(String args[]) {
           //加载kafka-cfg.properties。
           Properties kafkaProperties =  KafkaCfg.getKafkaProperties();
   
           Properties props = new Properties();
           //设置接入点，请通过控制台获取对应Topic的接入点。
           props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
           //两次Poll之间的最大允许间隔。
           //消费者超过该值没有返回心跳，服务端判断消费者处于非存活状态，服务端将消费者从Consumer Group移除并触发Rebalance，默认30s。
           props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 30000);
           //每次Poll的最大数量。
           //注意该值不要改得太大，如果Poll太多数据，而不能在下次Poll之前消费完，则会触发一次负载均衡，产生卡顿。
           props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 30);
           //消息的反序列化方式。
           props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
           props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
           //当前消费实例所属的消费组，请在控制台申请之后填写。
           //属于同一个组的消费实例，会负载消费消息。
           props.put(ConsumerConfig.GROUP_ID_CONFIG, kafkaProperties.getProperty(KafkaCfg.GROUP_ID));
   
           //生成一个消费实例。
           KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
           //设置消费组订阅的Topic，可以订阅多个。
           //如果GROUP_ID_CONFIG是一样，则订阅的Topic也建议设置成一样。
           List<String> subscribedTopics =  new ArrayList<String>();
           //如果需要订阅多个Topic，则在这里添加进去即可。
           //每个Topic需要先在控制台进行创建。
           String topicStr = kafkaProperties.getProperty(KafkaCfg.TOPIC);
           String[] topics = topicStr.split(",");
           for (String topic: topics) {
               subscribedTopics.add(topic.trim());
           }
           consumer.subscribe(subscribedTopics);
   
           //循环消费消息。
           while (true){
               try {
                   //必须在下次Poll之前消费完这些数据, 且总耗时不得超过SESSION_TIMEOUT_MS_CONFIG。
                   ConsumerRecords<String, String> records = consumer.poll(1000);
   
                   //建议开一个单独的线程池来消费消息，然后异步返回结果。
                   for (ConsumerRecord<String, String> record : records) {
                       System.out.println(String.format("Consume partition:%d offset:%d", record.partition(), record.offset()));
                       System.out.println(String.format("record key:%s, value:%s", record.key(), record.value()));
                   }
               } catch (Exception e) {
                   e.printStackTrace();
               }
           }
       }
   }
```



参考自定义应用发布流程发布到KDP运行。



**命令行访问**

请准备一个可以访问到2.1.1 kafka地址的kafka client环境

1. 环境变量准备

```
   export BOOTSTRAP=【请填写2.1.1获取的kafka url】
   export topic=【请填写2.1.2获取的topic】
```

2. 生产消息实践

   进入Kafka客户端文件的“/bin”目录下，执行如下命令进行生产消息：

```shell
   kafka-console-producer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic}
   test1#发送第1条消息
   test2#发送第2条消息
```

3. 消费者实践

   进入Kafka客户端文件的“/bin”目录下，执行如下命令从头消息消息：

```shell
   kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic} --from-beginning
```

如果只消费最新消息，执行如下命令：

```shell
   kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic}
```





### 3. 常见问题自检

#### 1. kafka连接异常

原因与排查：

1. 配置文件问题：请检查Kafka配置文件kafka-cfg.properties中的信息是否填写正确，使用命令行操作是变量信息是否正确。
2. kafka不可用：点击 "应用目录" - "Kafka"，查看运行实例中kafka-cluster运行情况并确认broker实例是否正常运行。

#### 2. 消费延迟增大

原因与排查：

1. 消息量激增：确认生产者消息量是否明显上升，导致消费者短时延迟升高。如果生产数据持续上升，请使用KDP资源弹性能力或扩容消费者。
2. kafka节点繁忙：确认kafka broker资源利用是否过高，可能受同kafka其他topic流量影响。建议将大流量业务需要的kafka进行拆分。

#### 3. 消息在分区中分布不均衡

原因与排查：

1. 发送消息时指定了消息Key：按照对应的Key发送消息至对应的分区，导致分区消息不均衡。可以通过同一个key落在同分区的特性在大数据使用时可能避免计算引擎shuffle操作。
2. 发送消息时指定了分区：会导致指定的分区有消息，未指定的分区没有消息。
3. 代码重新实现了分区分配策略：自定义的策略逻辑可能会导致分区消息不均衡。





### 4. 附录

#### 4.1. 概念介绍

**Broker**

一个 消息队列Kafka版服务端节点。 消息队列Kafka版提供全托管服务，会根据您的实例的流量规格自动变化Broker的数量和配置。您无需关心具体的Broker信息。

**kafka集群**

由多个Broker组成的集合。

**消息**

消息队列Kafka版中信息传递的载体。消息可以是网站的页面访问、服务器的日志，也可以是和CPU、内存相关的系统资源信息，但对于 消息队列Kafka版，消息就是一个字节数组。

**发布/订阅模型**

一种异步的服务间通讯模型。发布者无需了解订阅者的存在，直接将消息发送到特定的主题。订阅者无需了解发布者的存在，直接从特定的主题接收消息。 消息队列Kafka版支持发布/订阅模型。

**订阅关系**

Topic被 Group订阅的情况。 消息队列Kafka版支持查看订阅了指定Topic的在线 Group的情况，非在线 Group的情况无法查看。

**Producer**

向 消息队列Kafka版发送消息的应用。

**Consumer**

从 消息队列Kafka版接收消息的应用。

**Group**

一组具有相同Group ID的Consumer。当一个Topic被同一个 Group的多个Consumer消费时，每一条消息都只会被投递到一个Consumer，实现消费的负载均衡。通过 Group，您可以确保一个Topic的消息被并行消费。

**Topic**

消息的主题，用于分类消息。


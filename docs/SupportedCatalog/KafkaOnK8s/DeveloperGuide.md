# Kafka 开发指南

## 接入点获取

通过 KDP Web 的`大数据集群管理`->`集群信息`->`应用使用配置`。
查看`配置类型：kafka`的配置信息，其中`bootstrap_plain`为kafka broker的地址。

## Topic创建

请使用KDP提供的kafka manager或联系管理员创建需要使用的topic。

## 使用实践

### 未开启SASL访问实践

1. 安装Java依赖库

   在pom.xml中添加以下依赖。

```xml
   <dependency>
       <groupId>org.apache.kafka</groupId>
       <artifactId>kafka-clients</artifactId>
       <version>2.8.1</version>
   </dependency>
```

2. 创建Kafka配置文件kafka-cfg.properties

```properties
   ## 配置kafka接入点，在权限获取时申请获知。
   bootstrap.servers=【kafka url】
   ## 配置Topic，在权限获取时申请。
   topic=【准备使用的topic】
   ## 配置Consumer Group，自定义带用户id的字符串。
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
       }
   }
```

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

### 开启SASL访问实践

1. 安装Java依赖库

   在pom.xml中添加以下依赖。

```xml
   <dependency>
       <groupId>org.apache.kafka</groupId>
       <artifactId>kafka-clients</artifactId>
       <version>2.8.1</version>
   </dependency>
```

2. 创建Kafka配置文件kafka-cfg.properties

```properties
   ## 配置kafka接入点，在权限获取时申请获知。
   bootstrap.servers=【kafka url】
   ## 配置Topic，在权限获取时申请。
   topic=【topic】
   ## 配置Consumer Group，自定义带用户id的字符串。
   group.id=【自定义消费组名称】
   ## 配置kafka client运行环境中keytab文件路径
   sasl.keytab=【租户keytab存放在运行环境的文件路径】
   ## 配置sasl范围的principle
   sasl.principle=【principle信息】
```

3. 工具类准备

```java
   import java.util.Properties;
   
   public class KafkaCfg {
       private static Properties properties;
   
       public static final String BOOTSTRAP_SERVERS = "bootstrap.servers";
       public static final String TOPIC = "topic";
       public static final String GROUP_ID = "group.id";
       public static final String SASL_KEYTAB = "sasl.keytab";
       public static final String SASL_PRINCIPLE = "sasl.principle";
   
       public synchronized static Properties getKafkaProperties() {
           if (null != properties) {
               return properties;
           }
           // 获取配置文件kafka-cfg.properties
           Properties kafkaProperties = new Properties();
           try {
               kafkaProperties.load(KafkaCfg.class.getClassLoader().getResourceAsStream("kafka-cfg.properties"));
           } catch (Exception e) {
               // 配置加载失败，异常退出
               e.printStackTrace();
           }
           properties = kafkaProperties;
           return kafkaProperties;
       }
   }
```

```java
   import java.util.Properties;
   
   public class KafkaSecurityUtils {
       private KafkaSecurityUtils(){}
   
       private final static String SASL_JAAS_TEMPLATE = "com.sun.security.auth.module.Krb5LoginModule required"
               + " useKeyTab=true    storeKey=true    keyTab=\"%s\"   principal=%s;";
   
       public static void ConfigureKrb5KafkaClient(Properties kafkaProperties) {
           String saslJaasConfig = String.format(SASL_JAAS_TEMPLATE,
                   KafkaCfg.getKafkaProperties().get(KafkaCfg.SASL_KEYTAB),
                   KafkaCfg.getKafkaProperties().get(KafkaCfg.SASL_PRINCIPLE));
   
           kafkaProperties.put("security.protocol", "SASL_PLAINTEXT");
           kafkaProperties.put("sasl.mechanism", "GSSAPI");
           kafkaProperties.put("sasl.kerberos.service.name", "kafka");
           kafkaProperties.put("sasl.jaas.config", saslJaasConfig);
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
   
           //Kafka消息的序列化方式。
           props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           //请求的最长等待时间。
           props.put(ProducerConfig.MAX_BLOCK_MS_CONFIG, 30 * 1000);
           //设置客户端内部重试次数。
           props.put(ProducerConfig.RETRIES_CONFIG, 5);
           //设置客户端内部重试间隔。
           props.put(ProducerConfig.RECONNECT_BACKOFF_MS_CONFIG, 3000);
         
           //添加sasl安全访问配置
           KafkaSecurityUtils.ConfigureKrb5KafkaClient(props);
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
       }
   }
```

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
           
           //添加sasl安全访问配置
           KafkaSecurityUtils.ConfigureKrb5KafkaClient(props);
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

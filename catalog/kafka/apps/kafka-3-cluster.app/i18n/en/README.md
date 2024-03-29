### 1. Description

Kafka is a distributed event streaming platform used by thousands of companies for high-performance data pipelines, streaming analytics, data integration, and mission-critical applications.

### 2. Instruction

#### 2.1. Resources preparation
##### 2.1.1. **Get access point**

In KDP Big Data Cluster Management - Cluster Information - Application Usage Configuration, get the host and port in kafka-3-cluster-kafka-context.

##### 2.1.2. **Topic Creation**

Create by using Kafka manager or through Kafka command.

#### 2.2. Demo

**java program code**

1. Install the Java dependency library

   Add the following dependencies in pom.xml.

```xml
    <dependency>
        <groupId>org.apache.kafka</groupId>
        <artifactId>kafka-clients</artifactId>
        <version>3.4.1</version>
    </dependency>
```

2. Create the Kafka configuration file kafka-cfg.properties

```properties
    ## Configure the kafka access point
    bootstrap.servers=【kafka url obtained in 2.1.1 application】
    ## Configure Topic
    topic=[topic created or applied for in 2.1.2]
    ## Configure Consumer Group, customize the string with user id.
    group.id=【custom consumption group name】
```

3. Tools preparation

```java
    import java.util.Properties;
   
    public class KafkaCfg {
        private static Properties properties;
        public static final String BOOTSTRAP_SERVERS = "bootstrap. servers";
        public static final String TOPIC = "topic";
        public static final String GROUP_ID = "group.id";
     
     
        public synchronized static Properties getKafkaProperties() {
            if (null != properties) {
                return properties;
            }
            // Get the configuration file kafka-cfg.properties
            Properties kafkaProperties = new Properties();
            try {
                kafkaProperties.load(KafkaCfg.class.getClassLoader().getResourceAsStream("kafka-cfg.properties"));
            } catch (Exception e) {
                // Failed to load the configuration and exited abnormally.
                e.printStackTrace();
            }
            properties = kafkaProperties;
            return kafkaProperties;
        }
    }
```

4. Production message practice

```java
    import org.apache.kafka.clients.producer.KafkaProducer;
    import org.apache.kafka.clients.producer.ProducerConfig;
    import org.apache.kafka.clients.producer.ProducerRecord;
   
    import java.util.Properties;
   
    public class KdpKafkaProducer {
   
        public static void main(String args[]) {
            //Load kafka-cfg.properties.
            Properties kafkaCfgProperties = KafkaCfg. getKafkaProperties();
   
            Properties props = new Properties();
            //Set the access point, please obtain the access point corresponding to the topic through the console.
            props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaCfgProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
   
            //kafka ack message confirmation mechanism, 1 means that the leader will return after confirmation, and -1 means that all replicas need to be confirmed before returning
            props. put("acks", "1");
            //The serialization method of Kafka messages.
            props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
            props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
            //The maximum waiting time for the request.
            props.put(ProducerConfig.MAX_BLOCK_MS_CONFIG, 30 * 1000);
            //Set the number of internal retries of the client.
            props. put(ProducerConfig. RETRIES_CONFIG, 5);
            //Set the client's internal retry interval.
            props.put(ProducerConfig.RECONNECT_BACKOFF_MS_CONFIG, 3000);
            //Construct the Producer object, which is thread-safe.
            KafkaProducer<String, String> producer = new KafkaProducer<>(props);
   
            //Topic to which the message belongs
            String topic = kafkaCfgProperties. getProperty(KafkaCfg. TOPIC);
            // message key, can be null
            String key = "message key";
            //The content of the message, here is just a test string, in actual production scenarios, the message object is usually converted into a json or avro format string.
            String value = "this is the message's value";
   
            for (int i = 0; i< 100 ; i++) {
                ProducerRecord<String, String> record = new ProducerRecord<>(topic,
                        key + i,
                       value + i);
                producer. send(record);
            }
           producer.flush();
        }
    }
```



Publish to KDP to run by referring to the custom application publishing process.



5. Message consumption practices

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
            //Load kafka-cfg.properties.
            Properties kafkaProperties = KafkaCfg. getKafkaProperties();
   
            Properties props = new Properties();
            //Set the access point, please obtain the access point corresponding to the topic through the console.
            props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
            //The maximum allowable interval between two Polls.
            //The consumer does not return a heartbeat when the value exceeds this value. The server determines that the consumer is not alive. The server removes the consumer from the Consumer Group and triggers Rebalance. The default is 30s.
            props. put(ConsumerConfig. SESSION_TIMEOUT_MS_CONFIG, 30000);
            //The maximum number of each Poll.
            //Be careful not to change this value too much. If there is too much data in the Poll and cannot be consumed before the next Poll, it will trigger a load balancing and cause a freeze.
            props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 30);
            //The deserialization method of the message.
            props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
            props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
            //The consumption group to which the current consumption instance belongs, please fill in after the console application.
            //Consumption instances belonging to the same group will load consumption messages.
            props.put(ConsumerConfig.GROUP_ID_CONFIG, kafkaProperties.getProperty(KafkaCfg.GROUP_ID));
   
            //Generate a consumer instance.
            KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
            //Set the To of the consumer group subscriptionpic, you can subscribe to multiple.
            //If the GROUP_ID_CONFIG is the same, it is recommended to set the subscribed Topic to be the same.
            List<String> subscribedTopics = new ArrayList<String>();
            //If you need to subscribe to multiple Topics, just add them here.
            //Each Topic needs to be created in the console first.
            String topicStr = kafkaProperties. getProperty(KafkaCfg. TOPIC);
            String[] topics = topicStr. split(",");
            for (String topic: topics) {
                subscribedTopics. add(topic. trim());
            }
            consumer. subscribe(subscribedTopics);
   
            // Loop consumption message.
            while (true) {
                try {
                    //The data must be consumed before the next Poll, and the total time must not exceed SESSION_TIMEOUT_MS_CONFIG.
                    ConsumerRecords<String, String> records = consumer. poll(1000);
   
                    //It is recommended to open a separate thread pool to consume messages, and then return the results asynchronously.
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



Publish to KDP to run by referring to the custom application publishing process.



**Command line access**

Please prepare a kafka client environment that can access the 2.1.1 kafka address

1. Environment variable preparation

```
    export BOOTSTRAP=【Please fill in the kafka url obtained in 2.1.1】
    export topic=【Please fill in the topic obtained in 2.1.2】
```

2. Production message practice

   Enter the "/bin" directory of the Kafka client file, and execute the following command to produce messages:

```shell
    kafka-console-producer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic}
    test1#Send the first message
    test2#Send the second message
```

3. Consumer Practices

   Enter the "/bin" directory of the Kafka client file, and execute the following command to reset the message:

```shell
    kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic} --from-beginning
```

   To consume only the latest news, execute the following command:

```shell
    kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic}
```





### 3.  FAQs

#### 1. kafka connection exception
Cause and troubleshooting:
1. Configuration file problem: Please check whether the information in the Kafka configuration file kafka-cfg.properties is filled correctly, and whether the variable information is correct when using the command line operation.
2. Kafka is not available: click "Application Catalog" - "Kafka", enter kafka to search kafka and confirm whether the broker instance is running normally.

#### 2. Consumer group lag increases
Cause and troubleshooting:
1. Message volume surge: confirm whether the message volume of the producer has increased significantly, resulting in a short-term delay in the rise of consumers. If the production data continues to rise, please use KDP resource flexibility or expand the capacity of consumers.
2. Kafka node is busy: confirm whether kafka broker resource utilization is too high, which may be affected by traffic from other topics in the same kafka. It is recommended to split the kafka required for high-traffic services.

#### 3. Messages are not evenly distributed in the partition
Cause and troubleshooting:
1. The message key is specified when sending the message: send the message to the corresponding partition according to the corresponding key, resulting in message imbalance in the partition. The feature that the same key falls in the same partition can avoid the computation engine shuffle operation when using big data.
2. When sending a message, a partition is specified: the specified partition will have messages, and the unspecified partition will have no messages.
3. The code re-implemented the partition allocation policy: the customized policy logic may cause the partition message to be unbalanced.



### 4. Appendix

#### 4.1. Concept

**Broker**

A message queue Kafka server node. The message queue Kafka version provides a fully managed service, which will automatically change the number and configuration of Brokers according to the traffic specifications of your instance. You don't need to care about specific Broker information.

**kafka cluster**

A collection of multiple Brokers.

**information**

The carrier of information transmission in the message queue Kafka version. The message can be the page access of the website, the log of the server, or the system resource information related to CPU and memory, but for the message queue Kafka version, the message is a byte array.

**publish/subscribe model**

An asynchronous inter-service communication model. Publishers send messages directly to specific topics without knowing the existence of subscribers. Subscribers receive messages directly from specific topics without knowing the existence of publishers. The message queue for Kafka supports the publish/subscribe model.

**subscription relationship**

The situation that Topic is subscribed by Group. The Kafka version of the message queue supports viewing the status of online groups that have subscribed to a specified topic, and the status of offline groups cannot be viewed.

**Producer**

An application that sends messages to the Kafka version of the message queue.

**Consumer**

An application that receives messages from the message queue for Kafka.

**Group**

A group of Consumers with the same Group ID. When a topic is consumed by multiple consumers of the same group, each message will only be delivered to one consumer to achieve load balancing of consumption. With Group, you can ensure that the messages of a Topic are consumed in parallel.

**Topic**

The subject of the message, used to categorize the message.
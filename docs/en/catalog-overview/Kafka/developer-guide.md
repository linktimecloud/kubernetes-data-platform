# Kafka Developer Guide

## Access Point Acquisition

Obtain the access point through the KDP Web's `big data cluster management` -> `cluster information` -> `application usage configuration`.
Check the configuration type: `Kafka's configuration information`, where `bootstrap_plain` is the address of the Kafka broker.


## Topic Creation

Please use the Kafka Manager provided by KDP or contact the administrator to create the required topics.

## Usage Practice

### Without SASL Access

1. Install Java dependency libraries.

   Add the following dependency to pom.xml.

```xml
   <dependency>
       <groupId>org.apache.kafka</groupId>
       <artifactId>kafka-clients</artifactId>
       <version>2.8.1</version>
   </dependency>
```

2. Create the Kafka configuration file `kafka-cfg.properties`

```properties
   ## Configure Kafka access point, obtained during permission acquisition.
   bootstrap.servers=【kafka url】
   ## Configure the Topic, applied during permission acquisition.
   topic=【The topic prepared】
   ## Configure the Consumer Group, a custom string with user id.
   group.id=【Custom consumer group name】
```

3. Utility Class Preparation

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
           // Get kafka-cfg.properties
           Properties kafkaProperties = new Properties();
           try {
               kafkaProperties.load(KafkaCfg.class.getClassLoader().getResourceAsStream("kafka-cfg.properties"));
           } catch (Exception e) {
               // Configuration load failed, abnormal exit
               e.printStackTrace();
           }
           properties = kafkaProperties;
           return kafkaProperties;
       }
   }
```

1. Producing Messages

```java
   import org.apache.kafka.clients.producer.KafkaProducer;
   import org.apache.kafka.clients.producer.ProducerConfig;
   import org.apache.kafka.clients.producer.ProducerRecord;
   
   import java.util.Properties;
   
   public class KdpKafkaProducer {
   
       public static void main(String args[]) {
           //loading kafka-cfg.properties。
           Properties kafkaCfgProperties =  KafkaCfg.getKafkaProperties();
   
           Properties props = new Properties();
           //Set the access point, obtain the access point corresponding to the Topic through the console.
           props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaCfgProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
   
           //kafka ack message confirmation mechanism, 1 means return after leader confirmation, -1 means return after all replicas confirmation
           props.put("acks", "1");
           //Kafka message serialization method
           props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           ///Maximum waiting time for requests
           props.put(ProducerConfig.MAX_BLOCK_MS_CONFIG, 30 * 1000);
           //Set the number of retries within the client
           props.put(ProducerConfig.RETRIES_CONFIG, 5);
           //Set the retry interval within the client
           props.put(ProducerConfig.RECONNECT_BACKOFF_MS_CONFIG, 3000);
           //Construct a Producer object, which is thread-safe
           KafkaProducer<String, String> producer = new KafkaProducer<>(props);
   
           //The topic to which the message belongs
           String topic = kafkaCfgProperties.getProperty(KafkaCfg.TOPIC);
           //Message key, can be null
           String key = "message key";
          //The content of the message, here is just a test string, in actual production scenarios, it is often converted to json or avro format strings
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

5. Message Consumption

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
           //loading kafka-cfg.properties
           Properties kafkaProperties =  KafkaCfg.getKafkaProperties();
   
           Properties props = new Properties();
           //Set the access point, obtain the access point corresponding to the Topic through the console.
           props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
           //Maximum allowed interval between two Polls.
           //If the consumer does not return a heartbeat within this value, the server determines that the consumer is in a non-alive state, removes the consumer from the Consumer Group, and triggers Rebalance, default is 30s.
           props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 30000);
           //Maximum number of records for each Poll.
           //Note that this value should not be set too large. If too many data are polled and cannot be consumed before the next Poll, it will trigger a load balancing, causing a delay.
           props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 30);
           //Message deserialization method
           props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
           props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
           //The consumer group to which the current consumption instance belongs, please fill in after applying in the console.
           //Consumer instances belonging to the same group will load-balance message consumption.
           props.put(ConsumerConfig.GROUP_ID_CONFIG, kafkaProperties.getProperty(KafkaCfg.GROUP_ID));
   
           //Create a consumer instance
           KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
           //Set the Topic subscribed by the consumer group, you can subscribe to multiple.
           //If GROUP_ID_CONFIG is the same, it is recommended to set the subscribed Topic the same.
           List<String> subscribedTopics =  new ArrayList<String>();
           //If you need to subscribe to multiple Topics, add them here.
           //Each Topic needs to be created in the console first.
           String topicStr = kafkaProperties.getProperty(KafkaCfg.TOPIC);
           String[] topics = topicStr.split(",");
           for (String topic: topics) {
               subscribedTopics.add(topic.trim());
           }
           consumer.subscribe(subscribedTopics);
   
           //Loop to consume messages
           while (true){
               try {
                   //Must consume these data before the next Poll, and the total time consumed must not exceed SESSION_TIMEOUT_MS_CONFIG
                   ConsumerRecords<String, String> records = consumer.poll(1000);
   
                   //It is recommended to open a separate thread pool to consume messages, and then return results asynchronously.
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

### Enabling SASL Access 

1. Install Java Dependencies

   Add the following dependency to your pom.xml

```xml
   <dependency>
       <groupId>org.apache.kafka</groupId>
       <artifactId>kafka-clients</artifactId>
       <version>2.8.1</version>
   </dependency>
```

2. Create Kafka Configuration File `kafka-cfg.properties`

```properties
   ## Configure the Kafka access point, which is obtained when permissions are granted
   bootstrap.servers=【kafka url】
   ## Configure the Topic, obtained when permissions are granted
   topic=【topic】
   Configure the Consumer Group, with a custom string containing the user ID
   group.id=【Custom Consumer Group Name】
   ## Configure the path of the keytab file in the Kafka client runtime environment
   sasl.keytab=【Path to the keytab file stored in the runtime environment】
   ## Configure the principle of the SASL scope
   sasl.principle=【principle information】
```

3. Preparation of Utility Classes

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
           // Get the configuration file kafka-cfg.properties
           Properties kafkaProperties = new Properties();
           try {
               kafkaProperties.load(KafkaCfg.class.getClassLoader().getResourceAsStream("kafka-cfg.properties"));
           } catch (Exception e) {
               // Configuration loading failed, abnormal exit
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

1. Message Production

```java
   import org.apache.kafka.clients.producer.KafkaProducer;
   import org.apache.kafka.clients.producer.ProducerConfig;
   import org.apache.kafka.clients.producer.ProducerRecord;
   
   import java.util.Properties;
   
   public class KdpKafkaProducer {
   
       public static void main(String args[]) {
           //Load kafka-cfg.properties
           Properties kafkaCfgProperties =  KafkaCfg.getKafkaProperties();
   
           Properties props = new Properties();
           // Kafka message serialization method
           props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaCfgProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
   
           // Kafka message serialization method
           props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer");
           // Maximum waiting time for requests
           props.put(ProducerConfig.MAX_BLOCK_MS_CONFIG, 30 * 1000);
           // Set the number of retries within the client
           props.put(ProducerConfig.RETRIES_CONFIG, 5);
           // Set the retry interval within the client
           props.put(ProducerConfig.RECONNECT_BACKOFF_MS_CONFIG, 3000);
         
           // Add SASL security access configuration
           KafkaSecurityUtils.ConfigureKrb5KafkaClient(props);
           // Construct a Producer object, which is thread-safe
           KafkaProducer<String, String> producer = new KafkaProducer<>(props);
   
           // The topic to which the message belongs
           String topic = kafkaCfgProperties.getProperty(KafkaCfg.TOPIC);
           // Message key, can be null
           String key = "message key";
           // The content of the message, here is just a test string, in actual production scenarios, it is often converted to json or avro format strings
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

5. Message Consumption

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
           //load kafka-cfg.properties
           Properties kafkaProperties =  KafkaCfg.getKafkaProperties();
   
           Properties props = new Properties();
           // Set the access point, please obtain the access point corresponding to the Topic through the console.
           props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaProperties.getProperty(KafkaCfg.BOOTSTRAP_SERVERS));
           // Maximum allowed interval between two Polls.
           // If the consumer does not return a heartbeat within this value, the server determines that the consumer is in a non-alive state, removes the consumer from the Consumer Group, and triggers Rebalance, default is 30s.
           props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 30000);
           // Maximum number of records for each Poll.
           // Note that this value should not be set too large. If too many data are polled and cannot be consumed before the next Poll, it will trigger a load balancing, causing a delay.
           props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 30);
           // Message deserialization method
           props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
           props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringDeserializer");
           // The consumer group to which the current consumption instance belongs, please fill in after applying in the console.
           // Consumer instances belonging to the same group will load-balance message consumption.
           props.put(ConsumerConfig.GROUP_ID_CONFIG, kafkaProperties.getProperty(KafkaCfg.GROUP_ID));
           
           // Add SASL security access configuration
           KafkaSecurityUtils.ConfigureKrb5KafkaClient(props);
          // Create a consumer instance
           KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
           // Set the Topic subscribed by the consumer group, you can subscribe to multiple.
           // If GROUP_ID_CONFIG is the same, it is recommended to set the subscribed Topic the same.
           List<String> subscribedTopics =  new ArrayList<String>();
           // If you need to subscribe to multiple Topic, add them here.
           // Each Topic needs to be created in the console first.
           String topicStr = kafkaProperties.getProperty(KafkaCfg.TOPIC);
           String[] topics = topicStr.split(",");
           for (String topic: topics) {
               subscribedTopics.add(topic.trim());
           }
           consumer.subscribe(subscribedTopics);
   
           // Loop to consume messages
           while (true){
               try {
                   // Must consume these data before the next Poll, and the total time consumed must not exceed SESSION_TIMEOUT_MS_CONFIG.
                   ConsumerRecords<String, String> records = consumer.poll(1000);
   
                   // It is recommended to open a separate thread pool to consume messages, and then return results asynchronously.
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

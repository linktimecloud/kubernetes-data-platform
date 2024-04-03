# Kafka Basic Usage

## Connection Methods

Access the configuration through KDP Web's `big data cluster management` -> `cluster information` -> `application usage configuration`.
Check the configuration type: Kafka's `configuration information`, where `bootstrap_plain` is the address of the Kafka broker.

1. Operate through the command line by entering the Kafka broker terminal.

```shell
kubectl exec -it 【kafka broker pod name】 -n 【kafka namespace】 -- bash
```

2. Writing client code. Refer to the "04-developer-guide" for details.

### Operation Steps

Kafka connection access can be performed through both program code and shell command line.

**Command Line Access**

Prepare a Kafka client environment that can access the Kafka broker, or enter the Kafka broker terminal on Kubernetes for operations.

1. Environment Variable Preparation

```shell
   export BOOTSTRAP=【kafka url】
   export topic=【topic】
```

2. Producing Messages

   Enter the "/bin" directory of the Kafka client files and execute the following command to produce messages:

```shell
   kafka-console-producer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic}
   test1#send the 1st message
   test2#send the 2nd message
```

1. Consumer

   Enter the "/bin" directory of the Kafka client files and execute the following command to consume messages from the beginning:

```shell
   kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic} --from-beginning
```

Execute the following command for consuming the latest messages:

```shell
   kafka-console-consumer.sh --bootstrap-server ${BOOTSTRAP} --topic ${topic}
```

## partition Scaling

**Command Line Arguments Explanation**

--bootstrap-server specifies the Kafka service to connect to; if this parameter is present, --zookeeper is not required. -bootstrap-server localhost:9092

--replica-assignment replica partition assignment method; when modifying a topic, you can specify your own replica assignment situation.

--replica-assignment 0:1:2,3:4:5,6:7:8; where "0:1:2,3:4:5,6:7:8" indicates that the Topic TopicName has a total of 3 Partitions (separated by ","), and each Partition has 3 Replicas (separated by ":").

--topic topic name

--partitions  expand to a new number of partitions

**Kafka Shell Commands without Kerberos**

```shell
export BOOTSTRAP=【kafka url】
   export topic=【topic】
   
   echo '{
   "topics": [
   {"topic": "【replace to your topic name】"}
   ],
   "version": 1
   }' > move-json-file.json 
   
   bin/kafka-reassign-partitions.sh --bootstrap-server ${bootstrap} --topics-to-move-json-file move-json-file.json --broker-list "0,1,2" --generate
   # Write the reassignment plan obtained from the previous step into a file
   echo '【result of the previous command】' > reassignment-json-file.json
   bin/kafka-reassign-partitions.sh --bootstrap-server ${bootstrap} --reassignment-json-file reassignment-json-file.json --execute

```

**Kafka Shell Commands with Kerberos**

```shell
   echo 'KafkaClient {
       com.sun.security.auth.module.Krb5LoginModule required
       useKeyTab=true
       storeKey=true
       useTicketCache=false
       keyTab="【keytab file path】"
       principal="【principle】";
   };' > kafka_client_jaas.conf
   
   export KAFKA_CLIENT_JAAS_CONF=`pwd`/kafka_client_jaas.conf
   export KRB5_CONFIG=【krb5.conf file path】
   export KAFKA_OPTS="$KAFKA_OPTS -Djava.security.krb5.conf=$KRB5_CONFIG -Djava.security.auth.login.config=$KAFKA_CLIENT_JAAS_CONF"
   export BOOTSTRAP=【kafka url】
   export topic=【topic】
   
   echo '{
   "topics": [
   {"topic": "【replace to your topic name】"}
   ],
   "version": 1
   }' > move-json-file.json 
   
   bin/kafka-reassign-partitions.sh --bootstrap-server ${bootstrap} --command-config /tmp/client.conf --topics-to-move-json-file move-json-file.json --broker-list "0,1,2" --generate
   # Write the reassignment plan obtained from the previous step into a file
   echo '【result of the previous command】' > reassignment-json-file.json
   bin/kafka-reassign-partitions.sh --bootstrap-server ${bootstrap} --command-config /tmp/client.conf --reassignment-json-file reassignment-json-file.json --execute
   
```

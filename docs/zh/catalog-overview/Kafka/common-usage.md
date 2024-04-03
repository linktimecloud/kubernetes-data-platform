# Kafka 基础使用

## 连接方式

通过 KDP Web 的`大数据集群管理`->`集群信息`->`应用使用配置`。
查看`配置类型：kafka`的配置信息，其中`bootstrap_plain`为kafka broker的地址。

1. 可以通过命令行进入到kafka broker终端进行操作。

```shell
kubectl exec -it 【kafka broker pod name】 -n 【kafka namespace】 -- bash
```

2. 通过编写客户端代码进行访问。可参考04-developer-guide

### 操作步骤

kafka连接访问可以通过程序代码与shell命令行两种方式进行。

**命令行访问**

请准备一个可以访问到kafka broker的kafka client环境，或者进入kubernetes上的kafka broker终端进行操作。

1. 环境变量准备

```shell
   export BOOTSTRAP=【kafka url】
   export topic=【topic】
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

## partition扩缩容

**命令行参数说明**

--bootstrap-server 指定kafka服务 指定连接到的kafka服务; 如果有这个参数,则 --zookeeper可以不需要 –bootstrap-server localhost:9092

--replica-assignment 副本分区分配方式;修改topic的时候可以自己指定副本分配情况;

--replica-assignment 0:1:2,3:4:5,6:7:8 ；其中，“0:1:2,3:4:5,6:7:8”表示Topic TopicName一共有3个Partition（以“,”分隔），每个Partition均有3个Replica（以“:”分隔）

--topic topic名称

--partitions  扩展到新的分区数

**不开启 kerberos 的 kafka shell 命令行**

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
   # 将上一步得到的reassignment plan写入文件
   echo '【上条命令的结果】' > reassignment-json-file.json
   bin/kafka-reassign-partitions.sh --bootstrap-server ${bootstrap} --reassignment-json-file reassignment-json-file.json --execute

```

**开启 kerberos 的 kafka shell 命令行**

```shell
   echo 'KafkaClient {
       com.sun.security.auth.module.Krb5LoginModule required
       useKeyTab=true
       storeKey=true
       useTicketCache=false
       keyTab="【keytab文件路径】"
       principal="【principle】";
   };' > kafka_client_jaas.conf
   
   export KAFKA_CLIENT_JAAS_CONF=`pwd`/kafka_client_jaas.conf
   export KRB5_CONFIG=【krb5.conf文件路径】
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
   # 将上一步得到的reassignment plan写入文件
   echo '【上条命令的结果】' > reassignment-json-file.json
   bin/kafka-reassign-partitions.sh --bootstrap-server ${bootstrap} --command-config /tmp/client.conf --reassignment-json-file reassignment-json-file.json --execute
   
```

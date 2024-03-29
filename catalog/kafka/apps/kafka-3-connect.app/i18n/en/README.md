### 1. Description

Kafka Connect aims to simplify data integration and data stream processing for integrating external systems and data sources with Apache Kafka. Through Kafka Connect, users can import data from various data sources (such as databases, files, message queues, log files, etc.) into Kafka, and can also export data in Kafka to other systems for processing or storage.

Kafka Connect provides a standardized interface so that users can easily write, deploy and manage connectors without writing custom code. Connectors are components that enable data transfer between a specific data source and Kafka. Kafka Connect includes many built-in connectors, including JDBC connector, HDFS connector, Elasticsearch connector, and more.

Another key feature of Kafka Connect is scalability. It scales horizontally to handle large amounts of data and also automatically manages the assignment and reassignment of connectors and tasks. In addition, Kafka Connect also provides some advanced features, such as Transforms and Event Time Processing, which make data integration and data processing more flexible and efficient.

KDP provides a fully managed kafka connect service, providing users with an easy-to-use kafka connect service.

### 2. Instruction

#### 2.1. Start kafka connect tasks by kafka manager

##### 2.1.1. Component deployment

- Confirm that the kafka manager has been deployed.

- Confirm that kafka connect has been deployed.

##### 2.1.2. Resource preparation

- Use existing kafka topic or use the kafka manager to create it yourself. The topic name needs to match the connector settings. For example, the topic name for synchronizing mysql data is a custom prefix + table name.

##### 2.1.3. Connector task creation

1. Log in to kafka manager and click "connects" on the left menu bar to enter the kafka connect management interface.

2. Click the "Create a definition" button in the lower right corner of the page to create a connector task.

3. Prepare the user mysql and create a table for synchronous verification. In the following, we will use JdbcSourceConnector to read mysql data for illustration.

4. Select the connector to be used in "Types" to enter the parameter configuration page.

5. Please fill in the following parameters in the configuration list.

   | key | description | value |
   | ----- | ----- | ----- |
   | name | The name of the created connector task | Connector task name |
   | tasks.max | concurrent number of connector tasks, the default is 1 | concurrent tasks |
   | JDBC URL | jdbc connection address, port and database name | jdbc:mysql://[user mysql address]:[user mysql port]/[user database name] |
   | JDBC User | mysql username | user mysql username |
   | JDBC Password | mysql user password | user mysql user password |
   | Table Loading Mode | Data reading method | incrementing: each increment will not read duplicate data |
   | Table Whitelist | Table names to be synchronized, separated by "," | Target synchronization table names |
   | Topic Prefix | Write the topic name prefix, the target topic name is: prefix + tableName | Note that the filled prefix + table name is consistent with the topic name created in 2.1.2 |
   | incrementing.column.name | the column used for incremental reading | choose the primary key once |

6. Wait for the connector task to start.

7. Click "Topics" on the left menu bar to find the created Topic and check the data synchronization status.





#### 2.2. Use the console for practice

The following is an example of using the console to connect to Kafka Connect to import data from the MySQL database to Kafka

##### 2.2.1. Component deployment

- Confirm that kafka connect  has been deployed, and apply for access address and port.

##### 2.1.2. Resource preparation

- In KDP Big Data Cluster Management - Cluster Information - Application Usage Configuration, get the host and port in kafka-3-connect.

##### 2.1.3. Connector task creation

##### 2.1.3. Connector task creation

Next, create a MySQL database source connector to read data from MySQL and import it into Kafka. The key configuration and instructions are as follows:

| Name | Description |
| ------------------------ | --------------------------------------- |
| name | custom connector task name |
| connector.class | connector implementation class |
| tasks.max | Concurrent number of connector tasks, the default is 1 |
| connection.url | mysql connection information: address, port, user name, password |
| mode | Data reading mode |
| incrementing.column.name | column used for incremental reads |
| table.whitelist | Table names to be synchronized, separated by "," |
| topic.prefix | custom topic prefix |

Finally, start the connector:

```shell
curl -X POST http://【2.2.1 schema registry address】:【2.2.1 schema registry port】/connectors --header "content-Type:application/json" -d '{
     "name" : "【Custom connector task name】",
     "config":
     {
         "name": "【Custom connector task name, just the same as above】",
         "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
         "connection.user": "【mysql user name】",
         "connection.url": "jdbc:mysql://【mysql-address】:【mysql port】/kafka_manager?characterEncoding=utf8",
         "connection.password": "【mysql password】",
         "mode": "incrementing",
         "incrementing.column.name": "id",
         "transforms": "createKey, extractInt",
         "transforms.createKey.fields": "id",
         "transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
         "table.types": "TABLE",
         "table.whitelist": "kafka_manager.km_connection",
         "topic.creation.groups": "【User Table】",
         "topic.prefix": "【Custom topic prefix】",
         "topic.creation.default.replication.factor": 2,
         "topic.creation.default.partitions": 3
     }
}'

```

This connector uses the io.confluent.connect.jdbc.JdbcSourceConnector class, configured to connect to the "[user table]" in the MySQL database. incrementing.column.name specifies the column used for incremental reading, here is id. topic.prefix sets the Kafka topic prefix so that one topic is created per table in Kafka. This command will upload the connector configuration to Kafka Connect and start it.

At this point, Kafka Connect will read the data in the customers table from MySQL and import it into the topic named [custom topic prefix] + [user table] in Kafka.

### 3. Frequently Asked Questions

#### 1. Kafka connector start failed

Reason and troubleshooting:

1. Mysql configuration problem: Check whether the mysql binlog is enabled.
2. Mysql account permission problem: The following permissions are required: SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT, which can be authorized using the GRANT statement.
3. Kafka resource problem: Confirm that the kafka topic has been created.
4. Kafka connect configuration problem: Check whether the listed connector task configuration is correct.



#### 2. Slow data synchronization

Reason and troubleshooting:

1. Resource problem: Check whether Kafka connect resources are sufficient, and consider increasing the number of tasks to increase concurrency.
2. Kafka throughput: Whether it is affected by other topics of the same Kafka, you can consider splitting a large-traffic topic into an independent Kafka.
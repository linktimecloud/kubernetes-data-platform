### 1. Description

Kafka manager is a web application for managing and monitoring Kafka, kafka connect, schema registry. It provides an intuitive and easy-to-use user interface for one-click management of Kafka clusters and related components. The relevant capabilities are as follows:

1. Kafka cluster status monitoring: Kafka manager can monitor the status of Kafka cluster in real time, and can provide useful monitoring indicators, such as the number of messages, consumption delay, etc.
2. Topic management: Kafka manager allows you to easily manage topics in Kafka, such as creating topics, viewing topic messages, and so on.
3. Consumer group management: Kafka manager allows you to manage consumer groups in Kafka, such as viewing the consumer group consumption status, resetting the consumer group displacement, and so on.
4. Schema Registry management: Kafka manager allows you to manage the Schema Registry in Kafka, such as viewing the Schema Registry, creating, updating, and deleting Schemas, etc.
5. Kafka Connect management:

In general, Kafka manager is a very practical tool that can help you better manage and monitor Kafka clusters. If you're using Kafka and need a solid management tool, Kafka manager is an option worth considering.



### 2. Instructions

#### 2.1 Use by Kafka management

##### 2.1.1. Component deployment

- Confirm that the kafka manager has been deployed.

- Confirm that kafka has been deployed.

##### 2.1.2. brokers

- Click Clusters on the left menu bar to view the currently running broker information
- Click the query button on the right side of broker' to view broker configuration information

##### 2.1.3. Topic

- Log in to kafka manager

- Click Topics on the left menu bar to view the topics list and generate instructions as follows:

  | Name | Description |
     | -------------------- | ------------------------ |
  | Name | topic name |
  | Count | message data volume |
  | Size | total message size |
  | Last Record | The arrival time of the latest message |
  | Partitions Total | topic partition quantity |
  | Replications Factor | topic sets the number of replicas |
  | Replications In Sync | Number of replicas in sync |
  | Consumer Groups | Consumer group name and unconsumed data volume |

- Click the "Query" button on the right side of the topic to view data, partition, consumer, configuration, and replica file storage details.

- Click the "Configuration" button on the right side of the topic to modify the topic configuration.

- Click the "Delete" button on the right side of the topic to delete the topic.

#### 2.2. Schema Registry Management

##### 2.2.1. Component deployment

- Confirm that the kafka manager has been deployed.

- Confirm that the schema registry has been deployed.

##### 2.2.2. Create schema

1. Log in to Kafka Manager.

2. Click the schema registry on the left, and click the "Create a Subject" button at the bottom right of the page.

3. Enter the schema name in name, enter the following content in Schema and click "Create" in the lower right corner to create.

```json
    {
     "type": "record",
     "name": "KdpUser",
     "namespace": "com.kdp.example",
     "fields": [
        {
         "name": "name",
         "type": "string"
        },
        {
         "name": "favorite_number",
         "type": [
           "int",
           "null"
          ]
        },
        {
         "name": "favorite_color",
         "type": [
           "string",
           "null"
          ]
        }
      ]
    }
```

4. Check whether the created schema is successful.

##### 2.2.3. Modify schema

1. Log in to Kafka Manager.
2. Click the "Schema Registry" on the left, and click the View button on the right of the schema.
3. After modifying the information in Latest Schema, click Update to save.

##### 2.2.4. Delete schema

1. Log in to the KDP kafka manager.
2. Click the schema registry on the left, and click the delete button on the right of the schema.



#### 2.3. Use by restful api

##### 2.3.1. Component deployment

- Confirm that the kafka manager has been deployed.

- Confirm that kafka connect has been deployed.

##### 2.3.2. Connector task creation

Prepare user mysql and create a table for synchronous verification. Let’s say that we use JdbcSourceConnector to read mysql data for illustration. Make sure that mysql opens the binlog log, and the user account has the following permissions: SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT.

1. Log in to kafka manager and click "connects" on the left menu bar to enter the kafka connect management interface.

2. Click the "Create a definition" button in the lower right corner of the page to create a connector task.

3. Select the connector to be used in "Types" to enter the parameter configuration page.

4. Please fill in the following parameters in the configuration list.

   | variable name | variable description | value description |
   | --------- | ---------------------- | --------------- |
   | name | The name of the created connector task | Connector task name |
   | tasks.max | concurrent number of connector tasks, the default is 1 | concurrent tasks |
   | JDBC URL | jdbc connection address, port and database name | jdbc:mysql://[user mysql address]:[user mysql port]/[user database name] |
   | JDBC User | mysql username | user mysql username |
   | JDBC Password | mysql user password | user mysql user password |
   | Table Loading Mode | Data reading method | incrementing: each increment will not read duplicate data |
   | Table Whitelist | Table names to be synchronized, separated by "," | Target synchronization table names |
   | Topic Prefix | Write the topic name prefix, the target topic name is: prefix + tableName | Note that the filled prefix + table name is consistent with the topic name created in 2.1.2 |
   | incrementing.column.name | the column used for incremental reading | choose the primary key once |

5. Wait for the connector task to start.

6. Click "Topics" on the left menu bar to find the created Topic and check the data synchronization status.
### 1. 应用说明

Kafka Connect旨在简化数据集成和数据流处理，用于将外部系统和数据源与 Apache Kafka 集成。通过 Kafka Connect，用户可以将数据从各种数据源（例如数据库、文件、消息队列、日志文件等）导入到 Kafka，也可以将 Kafka 中的数据导出到其他系统进行处理或存储。

Kafka Connect 提供了一个标准化的接口，使得用户可以很容易地编写、部署和管理连接器（Connectors），而无需编写自定义代码。连接器是实现特定数据源和 Kafka 之间数据传输的组件。Kafka Connect 包含了许多内置的连接器，包括 JDBC 连接器、HDFS 连接器、Elasticsearch 连接器等。

Kafka Connect 的另一个关键特点是可扩展性。它可以水平扩展以处理大量数据，还可以自动管理连接器和任务的分配和重新分配。此外，Kafka Connect 还提供了一些高级功能，例如转换器（Transforms）和事件时间处理（Event Time Processing），使得数据集成和数据处理更加灵活和高效。

KDP提供全托管的kafka connect服务，为用户提供简单易用的kafka connect服务。

### 2. 快速入门

#### 2.1. 通过kafka manager进行实践

##### 2.1.1. 组件部署

- 确认kafka manager已部署。

- 确认kafka connect已部署。

##### 2.1.2. 资源准备

- 使用已有kafka topic或自行使用kafka manager创建topic，topic名称需要与connector设置匹配，如同步mysql数据topic名称为自定义前缀+表名。

##### 2.1.3. connector任务创建

1. 登录kafka manager点击左侧菜单栏"connects"，进入kafka connect管理界面。

2. 点击页面右下角"Create a definition"按钮进行connector任务创建。

3. 准备好用户mysql，创建一张表用于同步验证，以下说我们选用JdbcSourceConnector读取mysql数据进行说明。

4. 在"Types"中选择需要使用的connector进入参数配置页面。

5. 请在配置列表中完成以下参数填写。

   | 变量名                   | 变量说明                                             | 值说明                                                       |
      | ------------------------ | ---------------------------------------------------- | ------------------------------------------------------------ |
   | name                     | 创建connector任务的名称                              | connector任务名称                                            |
   | tasks.max                | connector任务并发数，默认为1                         | 任务并发数                                                   |
   | JDBC URL                 | jdbc连接地址、端口与数据库名称                       | jdbc:mysql://【用户mysql地址】:【用户mysql端口】/【用户数据库名称】 |
   | JDBC User                | mysql用户名                                          | 用户mysql用户名                                              |
   | JDBC Password            | mysql用户密码                                        | 用户mysql用户密码                                            |
   | Table Loading Mode       | 数据读取方式                                         | incrementing：增量每次不会读取重复数据                       |
   | Table Whitelist          | 需要同步的表名，使用","分隔                          | 目标同步表名                                                 |
   | Topic Prefix             | 写topic名称前缀，目标topic名称为：prefix + tableName | 注意填写的前缀+表名与2.1.2创建的topic名称一致                |
   | incrementing.column.name | 用于增量读取的列                                     | 一遍选用主键                                                 |

6. 等待connector任务启动。

7. 点击左侧菜单栏"Topics"找到已创建的Topic，查看数据同步情况。





#### 2.2. 使用控制台进行实践

以下是使用控制台连接 Kafka Connect 将 MySQL 数据库中的数据导入到 Kafka 的示例

##### 2.2.1. 组件部署

- KDP 大数据集群管理-集群信息-应用使用配置 kafka-3-connect 获得访问地址、端口。

##### 2.1.2. 资源准备

- 使用已有kafka topic或自行使用kafka manager创建topic，topic名称需要与connector设置匹配，如同步mysql数据topic名称为自定义前缀+表名。

##### 2.1.3. connector任务创建

接下来，创建一个 MySQL 数据库源连接器，以便从 MySQL 中读取数据并将其导入 Kafka，关键配置与说明如下：

##### 2.1.3. connector任务创建

接下来，创建一个 MySQL 数据库源连接器，以便从 MySQL 中读取数据并将其导入 Kafka，关键配置与说明如下：

| 名称                     | 说明                                    |
| ------------------------ | --------------------------------------- |
| name                     | 自定义connector任务名称                 |
| connector.class          | connector实现类                         |
| tasks.max                | connector任务并发数，默认为1            |
| connection.url           | mysql连接信息：地址、端口、用户名、密码 |
| mode                     | 数据读取方式                            |
| incrementing.column.name | 用于增量读取的列                        |
| table.whitelist          | 需要同步的表名，使用","分隔             |
| topic.prefix             | 自定义topic前缀                         |

最后，启动连接器：

```shell
curl -X POST http://【2.2.1获取访问地址】:【2.2.1获取访问访问端口】/connectors --header "content-Type:application/json" -d '{
    "name" : "【自定义connector任务名称】",
    "config" :
    {
        "name": "【自定义connector任务名称，与上面相同即可】",
        "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
        "connection.user": "【mysql用户名】",
        "connection.url": "jdbc:mysql://【mysql地址】:【mysql服务端口】/kafka_manager?characterEncoding=utf8",
        "connection.password": "【mysql用户密码】",
        "mode": "incrementing",
        "incrementing.column.name": "id",
        "transforms": "createKey,extractInt",
        "transforms.createKey.fields": "id",
        "transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
        "table.types": "TABLE",
        "table.whitelist": "kafka_manager.km_connection",
        "topic.creation.groups": "【用户表】",
        "topic.prefix": "【自定义topic前缀】",
        "topic.creation.default.replication.factor": 2,
        "topic.creation.default.partitions": 3
    }
}'

```

这个连接器使用了 io.confluent.connect.jdbc.JdbcSourceConnector 类，配置连接到 MySQL 数据库中的"【用户表】"。 incrementing.column.name 指定了用于增量读取的列，这里是 id。 topic.prefix 设置了 Kafka 主题的前缀，以便在 Kafka 中为每个表创建一个主题。该命令会将连接器配置上传到 Kafka Connect，并将其启动。

此时，Kafka Connect 将从 MySQL 中读取 customers 表中的数据，并将其导入 Kafka 中名为【自定义topic前缀】+【用户表】 的topic中。


### 3. 常见问题

#### 1. kafka connect启动失败

原因与排查：

1. mysql配置问题：确认mysql binlog是否开启。
2. mysql账号权限问题：需要以下权限SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT，可以使用GRANT语句进行授权。
3. kafka资源问题：确认kafka topic已创建。
4. kafka connect配置问题：检查列举的connector任务配置是否正确。



#### 2. 数据同步缓慢

原因与排查：

1. 资源问题：检查kafka connect资源是否足够，可以考虑提高task数量以加大并发度。
2. kafka吞吐量：是否受同kafka其他topic影响，可以考虑拆分大流量topic到独立kafka中。
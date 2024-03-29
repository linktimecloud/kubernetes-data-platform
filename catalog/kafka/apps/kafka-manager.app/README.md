### 1. 应用说明

Kafka manager是一个用于管理和监控Kafka、kafka connect、schema registry的web应用。它提供了一个直观易用的用户界面，便于一键化管理Kafka集群与相关组件。相关能力如下：

1. Kafka集群状态监控：Kafka manager可以实时监控Kafka集群的状态，并且可以提供有用的监控指标，例如消息数量、消费延迟情况等。
2. Topic管理：Kafka manager可以让您轻松地管理Kafka中的Topic，例如创建Topic、查看Topic消息等等。
3. Consumer组管理：Kafka manager可以让您管理Kafka中的Consumer组，例如查看Consumer组消费状态、重置Consumer组位移等等。
4. Schema Registry管理：Kafka manager可以让您管理Kafka中的Schema Registry，例如查看Schema注册表、创建、更新和删除Schema等等。
5. Kafka Connect管理：

总的来说，Kafka manager是一个非常实用的工具，可以帮助您更好地管理和监控Kafka集群。如果您正在使用Kafka并且需要一个可靠的管理工具，那么Kafka manager是一个值得考虑的选择。



### 2. 使用说明

#### 2.1 Kafka管理

##### 2.1.1. 组件部署

- 确认kafka manager已部署。

- 确认kafka已部署。

##### 2.1.2. broker

- 点击左侧菜单栏Clusters查看当前运行的broker信息
- 点击broker'右侧的查询按钮可查看broker配置信息

##### 2.1.3. Topic

- 登录kafka manager

- 点击左侧菜单栏Topics，查看topics列表产生说明如下：

  | 名称                 | 说明                     |
      | -------------------- | ------------------------ |
  | Name                 | topic名称                |
  | Count                | message数据量            |
  | Size                 | message总大小            |
  | Last Record          | 最新message达到时间      |
  | Partitions Total     | topic partition数量      |
  | Replications Factor  | topic设置副本数          |
  | Replications In Sync | 处于同步状态的副本数     |
  | Consumer Groups      | 消费组名称与未消费数据量 |

- 点击topic右侧"查询"按钮可以查看data、partition、消费者、配置、副本文件存储详细。

- 点击topic右侧"配置""按钮可以对topic配置进行修改。

- 点击topic右侧"删除"按钮会对topic进行删除。

#### 2.2. Schema Registry管理

##### 2.2.1. 组件部署

- 确认kafka manager已部署。

- 确认schema registry已部署。

##### 2.2.2. 创建schema

1. 登录kafka manager。

2. 点击左侧目录schema registry，点击页面右下方"Create a Subject"按钮。

3. 在name输入schema名称，在Schema输入如下内容点击右下角"Create"创建。

```json
   {
    "type":"record",
    "name":"KdpUser",
    "namespace":"com.kdp.example",
    "fields": [
       {
        "name":"name",
        "type":"string"
       },
       {
        "name":"favorite_number",
        "type": [
          "int",
          "null"
         ]
       },
       {
        "name":"favorite_color",
        "type": [
          "string",
          "null"
         ]
       }
     ]
   }
```

4. 查看创建的schema，是否成功。

##### 2.2.3. 修改schema

1. 登录kafka manager。
2. 点击左侧目录schema registry，点击schema右边的查看按钮。
3. 修改Latest Schema中的信息后点击Update保存。

##### 2.2.4. 删除schema

1. 登录KDP kafka manager。
2. 点击左侧目录schema registry，点击schema右边的删除按钮。



#### 2.3. Kafka Connect管理

##### 2.3.1. 组件部署

- 确认kafka manager已部署。

- 确认kafka connect已部署。

##### 2.3.2. connector任务创建

准备好用户mysql，创建一张表用于同步验证，以下说我们选用JdbcSourceConnector读取mysql数据进行说明，确保mysql开启binlog日志，并且使用账号具备以下权限：SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT。

1. 登录kafka manager点击左侧菜单栏"connects"，进入kafka connect管理界面。

2. 点击页面右下角"Create a definition"按钮进行connector任务创建。

3. 在"Types"中选择需要使用的connector进入参数配置页面。

4. 请在配置列表中完成以下参数填写。

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

5. 等待connector任务启动。

6. 点击左侧菜单栏"Topics"找到已创建的Topic，查看数据同步情况。
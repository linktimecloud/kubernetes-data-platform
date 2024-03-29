### 1. 应用说明

Schema Registry是一个用于管理与存储 Avro、JSON schema和 Protobuf schema类型元数据的服务。它根据特定的策略存储所有schema的历史版本提供多种兼容性设置，并允许根据兼容性配置限制schema的扩展。 它提供Kafka客户端的序列化程序，便于与kafka集成使用。

Schema Registry通过中心化的方式让不同的生产者和消费者共享和验证Schema，以保证数据的兼容性和一致性。生产者在将数据发送到Kafka时，将序列化数据用到的Schema存储在Schema Registry中。消费者在读取数据时，可以通过Schema Registry获得该的Schema并正确的完成数据反序列化。

Schema Registry提供了一种简单而可靠的方式，用于管理在Kafka中传输的数据格式，以确保数据的一致性。

### 2. 快速入门

#### 2.1. 通过kafka manager使用

##### 2.1.1. 组件部署

- 确认kafka manager已部署。

- 确认schema registry已部署。

##### 2.1.2. schema registry使用

**创建schema**

1. 登录KDP kafka manager

2. 点击左侧目录schema registry，点击页面右下方"Create a Subject"按钮

3. 在name输入schema名称，在Schema输入如下内容点击右下角"Create"创建

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

**修改schema**

1. 登录KDP kafka manager。
2. 点击左侧目录schema registry，点击schema右边的查看按钮。
3. 修改Latest Schema中的信息后点击Update保存。

**删除schema**

1. 登录KDP kafka manager。
2. 点击左侧目录schema registry，点击schema右边的删除按钮。



#### 2.2. 通过restful api使用

##### 2.2.1. 组件部署

- 确认kafka manager已部署。

- 确认schema registry已部署。

##### 2.2.2. 资源准备

- KDP 大数据集群管理-集群信息-应用使用配置 schema-registry 获得访问地址、端口

##### 2.2.3. schema registry使用

```shell
# 设置变量
export schema_registry_address=【2.2.2获取的schema registry地址】
export schema_registry_port=【2.2.2获取的schema registry端口】

# 添加一个名为"Kafka-key"的schema
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"schema": "{\"type\": \"string\"}"}' \
    http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-key/versions
  {"id":1}

# 添加一个名为"Kafka-value"的schema
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"schema": "{\"type\": \"string\"}"}' \
     http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions
  {"id":1}

# 查看所有schema
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects
  ["Kafka-value","Kafka-key"]

# 查看"Kafka-value"的所有版本
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions
  [1]

# 查看"Kafka-value"的所有版本
curl -X GET http://${schema_registry_address}:${schema_registry_port}/schemas/ids/1
  {"schema":"\"string\""}

# 获取"Kafka-value"版本1的信息
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions/1
  {"subject":"Kafka-value","version":1,"id":1,"schema":"\"string\""}

# 获取"Kafka-value"最新版本的信息
curl -X GET http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions/latest
  {"subject":"Kafka-value","version":1,"id":1,"schema":"\"string\""}

# 删除"Kafka-value"版本3
curl -X DELETE http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-value/versions/3
  3

# 查看"Kafka-key"是否存在
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"schema": "{\"type\": \"string\"}"}' \
    http://${schema_registry_address}:${schema_registry_port}/subjects/Kafka-key
  {"subject":"Kafka-key","version":1,"id":1,"schema":"\"string\""}

# 查看"Kafka-value"是否有兼容行设置
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"schema": "{\"type\": \"string\"}"}' \
    http://${schema_registry_address}:${schema_registry_port}/compatibility/subjects/Kafka-value/versions/latest
  {"is_compatible":true}

# 查看配置信息
curl -X GET http://${schema_registry_address}:${schema_registry_port}/config
  {"compatibilityLevel":"BACKWARD"}

# 更新"Kafka-value"的兼容配置为向后兼容
curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"compatibility": "BACKWARD"}' \
    http://${schema_registry_address}:${schema_registry_port}/config/Kafka-value
  {"compatibility":"BACKWARD"}
```

### 3. 常见问题

#### 1. schema registry无法更新

原因与排查：

1. 设置了compatibilityLevel为"BACKWARD"：如果设置了向后兼容，在更新时新版schema必须兼容旧版否则无法更新。




### 1. 简介

MongoDB 是一种文档数据库，它所具备的可扩展性和灵活性可以满足您对查询和索引的需求

### 基本概念

1. 文档（Document）
- MongoDB 存储数据的基本单位，类似于 JSON 对象，包含键值对。

2. 集合（Collection）
- 文档的容器，类似于关系数据库中的表。

3. 数据库（Database）
- 集合的物理容器，一个 MongoDB 服务器可以包含多个数据库。

4. 字段（Field）
- 文档中的键值对，用于存储具体的数据。

5. 索引（Index）
- 用于提高查询性能，支持多种类型的索引。

6. 查询（Query）
- 用于从 MongoDB 中检索数据的指令，支持丰富的查询语言。

7. 聚合（Aggregation）
- 用于处理数据记录并返回计算结果，提供聚合管道和 map-reduce 两种聚合框架。

8. 副本集（Replica Set）
- 一组 MongoDB 服务器，维护相同的数据副本，提供冗余和高可用性。

9. 分片（Sharding）
- 将数据分布在多个服务器上的过程，用于处理大量数据和高吞吐量的应用。


### 2. 快速开始


#### 使用 Python
```python
# Connect to MongoDB server
mongosh "mongodb://localhost:27017" -u "root" -p "root.password" 

# show databases
show dbs

# Select database
use mydatabase

# Create (Insert)
db.mycollection.insertOne({
    "name": "Alice",
    "age": 30,
    "email": "alice@example.com"
})

# Read (Find)
db.mycollection.find()

# Update
db.mycollection.updateOne(
    { "name": "Alice" },
    { $set: { "age": 31 } }
)

# Delete
db.mycollection.deleteOne({ "name": "Alice" })

# Drop collection
db.mycollection.drop()

# Drop database
db.dropDatabase()

```

#### 使用命令行
进入MongoDB Pod 容器

```bash
# Connect to MongoDB server
mongosh "mongodb://localhost:27017" -u "root" -p "root.password" 

# show databases
show dbs

# Select database
use mydatabase

# Create (Insert)
db.mycollection.insertOne({
    "name": "Alice",
    "age": 30,
    "email": "alice@example.com"
})

# Read (Find)
db.mycollection.find()

# Update
db.mycollection.updateOne(
    { "name": "Alice" },
    { $set: { "age": 31 } }
)

# Delete
db.mycollection.deleteOne({ "name": "Alice" })

# Drop collection
db.mycollection.drop()

# Drop database
db.dropDatabase()

```


### 3. FAQ

1. 如何减少 Shard 的数量？
请参考 https://www.mongodb.com/docs/manual/tutorial/remove-shards-from-cluster/
由于 shard 是 k8s satefulset 负载， 因此需要移除序号最大的 shard ， 如 mongodb-sharded-shard-<max-number> 
然后在KDP调整 shard 数量

2. 生产环境中， 如何配置组件数量？
https://www.mongodb.com/docs/manual/core/sharded-cluster-components/#production-configuration



https://www.mongodb.com/docs/manual/faq/



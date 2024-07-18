### 1. 简介

Elasticsearch 是一个基于 Lucene 库的分布式搜索和分析引擎，广泛用于全文搜索、结构化搜索、分析

#### 基本概念

1. 索引（Index）
定义：索引是具有相似特征的文档的集合。类似于关系数据库中的数据库。
操作：可以创建、删除和修改索引。

2. 类型（Type）
定义：类型是索引中的一个逻辑分类/分区，允许在同一个索引中存储不同类型的文档。但在 Elasticsearch 6.x 及之后的版本中，一个索引只能有一个类型。
注意：在 Elasticsearch 7.x 及之后的版本中，类型已被移除。

3. 文档（Document）
定义：文档是 Elasticsearch 中的基本信息单元，以 JSON 格式表示。类似于关系数据库中的行。
操作：可以添加、删除、更新和查询文档。

4. 字段（Field）
定义：字段是文档中的一个属性，类似于关系数据库中的列。
类型：字段可以有不同的数据类型，如字符串、整数、布尔值等。

5. 映射（Mapping）
定义：映射定义了索引中字段的类型和属性，类似于关系数据库中的表结构。
操作：可以手动定义映射，也可以让 Elasticsearch 自动生成。

6. 查询（Query）
定义：查询是用于从 Elasticsearch 中检索文档的请求。
类型：包括全文查询、匹配查询、布尔查询等。

7. 聚合（Aggregation）
定义：聚合用于对数据进行统计和分析，类似于 SQL 中的 GROUP BY 和聚合函数。
类型：包括指标聚合（如平均值、总和）、桶聚合（如范围、日期直方图）等。

8. 分片（Shard）
定义：分片是索引的一个水平分区，每个分片是一个独立的 Lucene 索引。
目的：分片允许水平扩展和并行处理，提高性能和可靠性。

9. 副本（Replica）
定义：副本是分片的复制，用于提供高可用性和故障恢复。
操作：可以动态调整副本的数量。

10. 节点（Node）
定义：节点是 Elasticsearch 集群中的一个服务器，负责存储数据并参与集群的索引和搜索操作。
类型：包括主节点、数据节点、协调节点等。

11. 集群（Cluster）
定义：集群是多个节点的集合，共同存储整个数据集合并提供联合索引和搜索功能。
操作：可以动态添加和删除节点。

12. 索引模板（Index Template）
定义：索引模板定义了新创建索引的默认设置和映射。
目的：简化索引创建过程，确保一致性。

13. 别名（Alias）
定义：别名是一个指向一个或多个索引的指针，允许在不修改应用代码的情况下切换索引。
操作：可以创建、删除和更新别名。

14. 分析器（Analyzer）
定义：分析器用于将文本转换为词项（tokens），包括字符过滤器、分词器和词项过滤器。
目的：提高搜索的准确性和相关性。


### 2. 快速开始

```bash

# Set environment variables
export ES_ENDPOINT=http://elasticsearch-kdp-data.kdp-e2e.io
export ES_INDEX=example-rest-curl-$(date +%s)

# Create an index
curl -X POST "${ES_ENDPOINT}/${ES_INDEX}/_doc?pretty" -H 'Content-Type: application/json' -d'
{
  "@timestamp": "2099-05-06T16:21:15.000Z",
  "event": {
    "original": "192.0.2.42 - - [06/May/2099:16:21:15 +0000] \"GET /images/bg.jpg HTTP/1.0\" 200 24736"
  }
}
'
# Get the mapping of an index
curl -X GET "${ES_ENDPOINT}/${ES_INDEX}/_mapping?pretty"

# Add multiple documents to an index
curl -X PUT "${ES_ENDPOINT}/${ES_INDEX}/_bulk?pretty" -H 'Content-Type: application/json' -d'
{ "create": { } }
{ "@timestamp": "2099-05-07T16:24:32.000Z", "event": { "original": "192.0.2.242 - - [07/May/2020:16:24:32 -0500] \"GET /images/hm_nbg.jpg HTTP/1.0\" 304 0" } }
{ "create": { } }
{ "@timestamp": "2099-05-08T16:25:42.000Z", "event": { "original": "192.0.2.255 - - [08/May/2099:16:25:42 +0000] \"GET /favicon.ico HTTP/1.0\" 200 3638" } }
'

# Search data in an index
curl -X GET "${ES_ENDPOINT}/${ES_INDEX}/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "event.original": "favicon.ico"
    }
  }
}
'

#  Delete an index
curl -X DELETE "${ES_ENDPOINT}/${ES_INDEX}?pretty"

```



### 3. FAQ

1. Elasticsearch 有哪些常用 node role ?

- 主节点（Master-eligible Node）:有资格被选举为主节点的节点。主节点负责管理集群的状态，包括创建和删除索引、跟踪集群中的节点以及分配分片到节点等。
- 数据节点（Data Node）:负责存储数据并执行数据相关的操作，如搜索和聚合。数据节点处理与数据存储和查询相关的负载。
- 协调节点（Coordinating Node）:负责接收客户端请求，将请求分发到相应的数据节点，并收集结果返回给客户端。每个节点默认都是协调节点，但可以通过配置专门指定某些节点为协调节点。
- 摄取节点（Ingest Node）:负责执行预处理管道，对文档进行转换和 enrich 操作。摄取节点在索引文档之前对文档进行预处理。


> https://www.elastic.co/guide/en/elasticsearch/reference/8.14/troubleshooting.html




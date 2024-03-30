# Hive 常见问题

## 内存问题引起的报错

### Container内存不足引起的OOM

报错日志：`java.lang.OutOfMemoryError: GC overhead limit exceeded或者java.lang.OutOfMemoryError: Java heap space`。

解决方法：调大Container的内存

```shell
set spark.executor.memory=4g;
```

### 部分GroupBy语句引起的OOM

报错日志：

```log
22/11/28 08:24:43 ERROR Executor: Exception in task 1.0 in stage 0.0 (TID 0)
java.lang.OutOfMemoryError: GC overhead limit exceeded
    at org.apache.hadoop.hive.ql.exec.GroupByOperator.updateAggregations(GroupByOperator.java:611)
    at org.apache.hadoop.hive.ql.exec.GroupByOperator.processHashAggr(GroupByOperator.java:813)
    at org.apache.hadoop.hive.ql.exec.GroupByOperator.processKey(GroupByOperator.java:719)
    at org.apache.hadoop.hive.ql.exec.GroupByOperator.process(GroupByOperator.java:787)
    at org.apache.hadoop.hive.ql.exec.Operator.forward(Operator.java:897)
    at org.apache.hadoop.hive.ql.exec.SelectOperator.process(SelectOperator.java:95)
    at org.apache.hadoop.hive.ql.exec.Operator.forward(Operator.java:897)
    at org.apache.hadoop.hive.ql.exec.TableScanOperator.process(TableScanOperator.java:130)
    at org.apache.hadoop.hive.ql.exec.MapOperator$MapOpCtx.forward(MapOperator.java:148)
    at org.apache.hadoop.hive.ql.exec.MapOperator.process(MapOperator.java:547)
```

原因分析：GroupBy的HashTable占用太多内存导致OOM。

解决方法：

1. 减小Split Size至128 MB、64 MB或更小，增大作业并发度：`mapreduce.input.fileinputformat.split.maxsize=134217728`或 `mapreduce.input.fileinputformat.split.maxsize=67108864`。
2. 通过增大 `spark.executor.instances` 增加并发数。
3. 通过 `spark.executor.memory` 增大 spark executor 内存。

## 元数据相关报错

### Drop大分区表超时

报错日志：

```log
FAILED: Execution ERROR, return code 1 from org.apache.hadoop.hive.ql.exec.DDLTask. org.apache.thrift.transport.TTransportException: java.net.SocketTimeoutException: Read timeout
```

原因分析：作业异常的可能原因是表分区太多，Drop耗时较长，导致Hive Metastore client网络超时。

解决方法：

1. 在KDP的 hive-metastore 应用的配置页面，找到 hiveSite 节点，调大Client访问metastore的超时时间。

```yaml
hive.metastore.client.socket.timeout=1200s
```

2. 批量删除分区，例如多次执行带条件的分区。

```sql
alter table [TableName] DROP IF EXISTS PARTITION (ds<='20220720')
```

## 其他异常

### select count(1)结果为0

原因分析：select count(1)使用的是Hive表统计信息（statistics），但这张表的统计信息不准确。

解决方法：修改配置不使用统计信息。

```yaml
hive.compute.query.using.stats=false
```

或者使用analyze命令重新统计表统计信息。

```sql
analyze table <table_name> compute statistics;
```

### 数据倾斜导致的作业异常

异常现象：

- Shuffle数据把磁盘打满。
- 某些Task执行时间特别长。
- 某些Task或Container出现OOM。

解决方法：

1. 打开Hive skewjoin优化。

```shell
set hive.optimize.skewjoin=true;
```

2. 通过增大 `spark.executor.instances` 增加并发数。
3. 通过 `spark.executor.memory` 增大 spark executor 内存。

## 常见问题

### 为什么Hive创建的外部表没有数据

问题描述：创建完外部表后查询没有数据返回。

外部表创建语句示例如下。

```sql
CREATE EXTERNAL TABLE storage_log(content STRING) PARTITIONED BY (ds STRING)
    ROW FORMAT DELIMITED
    FIELDS TERMINATED BY '\t'
    STORED AS TEXTFILE
    LOCATION 'hdfs:///your-logs/airtake/pro/storage';
```

查询没有数据返回。

```sql
select * from storage_log;
```

问题分析：Hive不会自动关联指定Partitions目录。

解决方法：

需要您手动指定Partitions目录。

```sql
alter table storage_log add partition(ds=123);
```

查询返回数据。

```sql
select * from storage_log;
```

返回如下数据。

```sql
  OK
abcd    123
efgh    123
```

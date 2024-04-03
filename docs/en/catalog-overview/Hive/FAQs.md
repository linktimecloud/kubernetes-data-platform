# Hive FAQs

## Memory Issues 

### Container Memory Insufficiency Causing OOM (Out of Memory)

Error Log:`java.lang.OutOfMemoryError: GC overhead limit exceeded or java.lang.OutOfMemoryError: Java heap space`.

Solution: Increase the memory allocated to the Container.

```shell
set spark.executor.memory=4g;
```

### OOM Caused by Some GroupBy Statements

Error Log:

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

Root Cause：The HashTable used by GroupBy is consuming too much memory, leading to an Out of Memory (OOM) error.

Solutions：

1. Decrease the Split Size to 128 MB, 64 MB, or smaller to increase the job concurrency: set `mapreduce.input.fileinputformat.split.maxsize=134217728` or `mapreduce.input.fileinputformat.split.maxsize=67108864` in the configuration.
2. Increase the number of concurrent tasks by raising the value of `spark.executor.instances`.
3. Enhance the memory allocation for Spark executors by adjusting the `spark.executor.memory` parameter to a higher value.

## Metadata-related Errors

### Timeout When Dropping Large Partitioned Tables

Error Log:

```log
FAILED: Execution ERROR, return code 1 from org.apache.hadoop.hive.ql.exec.DDLTask. org.apache.thrift.transport.TTransportException: java.net.SocketTimeoutException: Read timeout
```

Root Cause：The possible reason for the job exception is that there are too many table partitions, which leads to a prolonged drop operation and ultimately results in a network timeout for the Hive Metastore client.

Solutions:

1. In the configuration page of the KDP hive-metastore application, locate the hiveSite node and increase the timeout period for the client to access the metastore.

```yaml
hive.metastore.client.socket.timeout=1200s
```

2. Perform batch deletion of partitions, for example, by executing multiple conditions for partition drops.

```sql
alter table [TableName] DROP IF EXISTS PARTITION (ds<='20220720')
```

## Other Exceptions

### Select count(1) Resulting in 0

Root Cause：The select count(1) query utilizes Hive table statistics (statistics), but the statistics for this table are inaccurate.

Solutions：Modify the configuration to disable the use of statistics.

```yaml
hive.compute.query.using.stats=false
```

Or use the analyze command to recalculate the table statistics.

```sql
analyze table <table_name> compute statistics;
```

### Job Exceptions Caused by Data Skew

Symptoms:

- Shuffle data filling up the disk.
- Some tasks taking an unusually long time to execute.
- Some tasks or containers experiencing Out of Memory (OOM).

Solutions:

1. Enable Hive skew join optimization.

```shell
set hive.optimize.skewjoin=true;
```

2. Increase the number of concurrent tasks by raising the value of `spark.executor.instances`.

3. Enhance the memory allocation for Spark executors by adjusting the `spark.executor.memory` parameter to a higher value.

## Common Issues

### Why Are There No Data in External Tables Created by Hive?

Problem Description: After creating an external table, the query returns no data.

An example of an external table creation statement is as follows.

```sql
CREATE EXTERNAL TABLE storage_log(content STRING) PARTITIONED BY (ds STRING)
    ROW FORMAT DELIMITED
    FIELDS TERMINATED BY '\t'
    STORED AS TEXTFILE
    LOCATION 'hdfs:///your-logs/airtake/pro/storage';
```

Query returns no data.

```sql
select * from storage_log;
```

Root Cause: Hive does not automatically associate the specified Partitions directory.



Solutions：

Manually specify the Partitions directory.

```sql
alter table storage_log add partition(ds=123);
```

Query returns data.

```sql
select * from storage_log;
```

Data returned as follows.

```sql
  OK
abcd    123
efgh    123
```

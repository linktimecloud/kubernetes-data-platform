# Hive 最佳实践

## Hive 作业调优

### 数据清洗

- 读取表时分区过滤，避免全表扫描。
- 数据过滤之后再 JOIN。
- 重复使用数据时，避免重复计算，构建中间表，重复使用中间表。

### 多 Distinct 优化

优化前代码。多个 Distinct 时，数据会出现膨胀。

```sql
select k,count(distinct case when a > 1 then user_id) user1,
       count(distinct case when a > 2 then user_id) user2,
       count(distinct case when a > 3 then user_id) user3,
       count(distinct case when a > 4 then user_id) user4
from t  
group by k
```

优化后代码。通过两次 Group By 的方式代替 Distinct 操作，通过内层的 Group By 去重并降低数据量，通过外层的 Group By 取 sum，即可实现 Distinct 的效果。

```sql
select k,sum(case when user1 > 0 then 1 end) as user1,
       sum(case when user2 > 0 then 1 end) as user2,
       sum(case when user3 > 0 then 1 end) as user3,
       sum(case when user4 > 0 then 1 end) as user4
from 
        (select k,user_id,count(case when a > 1 then user_id) user1,
                count(case when a > 2 then user_id) user2,
                count(case when a > 3 then user_id) user3,
                count(case when a > 4 then user_id) user4
        from t
        group by k,user_id  
        ) tmp 
group by k
```

### 数据倾斜

如果是 Group By 出现热点，请按照以下方法操作：

先开启 Map 端聚合。

```shell
set hive.map.aggr=true;
set hive.groupby.mapaggr.checkinterval=100000;（用于设定Map端进行聚合操作的条目数）
```

可以对 Key 随机化打散，多次聚合，或者直接设置。

```shell
set hive.groupby.skewindata=true;
```

当选项设定为 true 时，生成的查询计划有两个 MapReduce 任务。在第一个 MapReduce 中，Map 的输出结果集合会随机分布到 Reduce 中， 每个部分进行聚合操作，并输出结果。这样处理的结果是，相同的 Group By Key 有可能分发到不同的 Reduce 中，从而达到负载均衡的目的；第二个 MapReduce 任务再根据预处理的数据结果按照 Group By Key 分布到 Reduce 中（这个过程可以保证相同的 Group By Key 分布到同一个 Reduce 中），最后完成最终的聚合操作。

如果两个大表进行 JOIN 操作时，出现热点，则使用热点 Key 随机化。

例如，log 表存在大量 user_id 为 null 的记录，但是表 bmw_users 中不会存在 user_id 为空，则可以把 null 随机化再关联，这样就避免 null 值都分发到一个 Reduce Task 上。代码示例如下。

```sql
SELECT * FROM log a LEFT OUTER 
JOIN bmw_users b ON 
CASE WHEN a.user_id IS NULL THEN CONCAT(‘dp_hive’,RAND()) ELSE a.user_id=b.user_id END;
```

如果大表和小表进行 JOIN 操作时，出现热点，则使用 MAP JOIN。

### Spark driver/executor 参数

可以通过指定 spark driver/executor 的资源和数量来提高速度。

```shell
set spark.driver.cores=1;
set spark.driver.memory=2g;
set spark.executor.cores=2;
set spark.executor.memory=4g;
set spark.executor.instances=4;
```

更多参数可以参考 Apache Spark [官方文档](https://spark.apache.org/docs/latest/configuration.html#application-properties)。

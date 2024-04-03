# Hive Best Practices

## Hive Job Optimization

### Data Cleaning

- Apply partition filtering when reading tables to avoid full table scans.
- Perform data filtering before joining.
- When reusing data, avoid redundant calculations by constructing intermediate tables and reusing them.

### Multiple Distinct Optimization

Before optimization code. With multiple Distincts, data can become bloated.

```sql
select k,count(distinct case when a > 1 then user_id) user1,
       count(distinct case when a > 2 then user_id) user2,
       count(distinct case when a > 3 then user_id) user3,
       count(distinct case when a > 4 then user_id) user4
from t  
group by k
```

After optimization code. Replace Distinct operations with two Group Bys, using the inner Group By for deduplication and reducing data volume, and the outer Group By for summing to achieve the effect of Distinct.

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

### Data Skew

If a hotspot occurs during Group By:

First, enable Map-side aggregation.

```shell
set hive.map.aggr=true;
#（Sets the number of entries for Map-side aggregation）
set hive.groupby.mapaggr.checkinterval=100000;

```

Randomize the Key to scatter the data and perform multiple aggregations, or set it directly.

```shell
set hive.groupby.skewindata=true;
```

When set to true, the generated query plan has two MapReduce tasks. In the first MapReduce, the Map output is randomly distributed to the Reduce, where each part performs an aggregation operation and outputs the result. This process may distribute the same Group By Key to different Reduces, achieving load balancing. The second MapReduce task then distributes the pre-processed data according to the Group By Key to the Reduce (this process ensures the same Group By Key is distributed to the same Reduce), and finally completes the final aggregation.

If a hotspot occurs when joining two large tables, use hotspot Key randomization.

For example, if the log table has a large number of records with null user_id, but the bmw_users table does not have null user_id, you can randomize the nulls and then join, avoiding all null values being sent to one Reduce Task. The code example is as follows.

```sql
SELECT * FROM log a LEFT OUTER 
JOIN bmw_users b ON 
CASE WHEN a.user_id IS NULL THEN CONCAT(‘dp_hive’,RAND()) ELSE a.user_id=b.user_id END;
```

If a hotspot occurs when joining a large table with a small table, use MAP JOIN.

### Spark Driver/Executor Parameters

You can improve speed by specifying the resources and number of Spark drivers and executors.

```shell
set spark.driver.cores=1;
set spark.driver.memory=2g;
set spark.executor.cores=2;
set spark.executor.memory=4g;
set spark.executor.instances=4;
```

More parameters can be referenced in the [Apache Spark documentation](https://spark.apache.org/docs/latest/configuration.html#application-properties).

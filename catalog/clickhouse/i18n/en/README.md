# Introduction

ClickHouse is a high-performance, column-oriented SQL database management system (DBMS) for online analytical processing (OLAP). 

## Distinctive Features

### True Column-Oriented Database Management System

In a real column-oriented DBMS, no extra data is stored with the values. This means that constant-length values must be supported to avoid storing their length “number” next to the values. For example, a billion UInt8-type values should consume around 1 GB uncompressed, or this strongly affects the CPU use. It is essential to store data compactly (without any “garbage”) even when uncompressed since the speed of decompression (CPU usage) depends mainly on the volume of uncompressed data.

This is in contrast to systems that can store values of different columns separately, but that cannot effectively process analytical queries due to their optimization for other scenarios, such as HBase, BigTable, Cassandra, and HyperTable. You would get throughput around a hundred thousand rows per second in these systems, but not hundreds of millions of rows per second.

Finally, ClickHouse is a database management system, not a single database. It allows creating tables and databases in runtime, loading data, and running queries without reconfiguring and restarting the server.

### Data Compression

Some column-oriented DBMSs do not use data compression. However, data compression plays a key role in achieving excellent performance.

In addition to efficient general-purpose compression codecs with different trade-offs between disk space and CPU consumption, ClickHouse provides specialized codecs for specific kinds of data, which allow ClickHouse to compete with and outperform more niche databases, like time-series ones.

### Disk Storage of Data

Keeping data physically sorted by primary key makes it possible to extract data based on specific values or value ranges with low latency in less than a few dozen milliseconds. Some column-oriented DBMSs, such as SAP HANA and Google PowerDrill, can only work in RAM. This approach requires allocation of a larger hardware budget than necessary for real-time analysis.

ClickHouse is designed to work on regular hard drives, which means the cost per GB of data storage is low, but SSD and additional RAM are also fully used if available.

### Parallel Processing on Multiple Cores

Large queries are parallelized naturally, taking all the necessary resources available on the current server.

### Distributed Processing on Multiple Servers

Almost none of the columnar DBMSs mentioned above have support for distributed query processing.

In ClickHouse, data can reside on different shards. Each shard can be a group of replicas used for fault tolerance. All shards are used to run a query in parallel, transparently for the user.

### SQL Support

ClickHouse supports a declarative query language based on SQL that is identical to the ANSI SQL standard in many cases.

Supported queries include GROUP BY, ORDER BY, subqueries in FROM, JOIN clause, IN operator, window functions and scalar subqueries.

Correlated (dependent) subqueries are not supported at the time of writing but might become available in the future.

### Vector Computation Engine

Data is not only stored by columns but is processed by vectors (parts of columns), which allows achieving high CPU efficiency.

### Real-Time Data Inserts

ClickHouse supports tables with a primary key. To quickly perform queries on the range of the primary key, the data is sorted incrementally using the merge tree. Due to this, data can continually be added to the table. No locks are taken when new data is ingested.

### Primary Indexes

Having data physically sorted by primary key makes it possible to extract data based on specific values or value ranges with low latency in less than a few dozen milliseconds.

### Secondary Indexes

Unlike other database management systems, secondary indexes in ClickHouse do not point to specific rows or row ranges. Instead, they allow the database to know in advance that all rows in some data parts would not match the query filtering conditions and do not read them at all, thus they are called data skipping indexes.

### Suitable for Online Queries

Most OLAP database management systems do not aim for online queries with sub-second latencies. In alternative systems, report building time of tens of seconds or even minutes is often considered acceptable. Sometimes it takes even more time, which forces systems to prepare reports offline (in advance or by responding with “come back later”).

In ClickHouse "low latency" means that queries can be processed without delay and without trying to prepare an answer in advance, right at the same moment as the user interface page is loading. In other words, online.

### Support for Approximated Calculations

ClickHouse provides various ways to trade accuracy for performance:

Aggregate functions for approximated calculation of the number of distinct values, medians, and quantiles.
Running a query based on a part (sample) of data and getting an approximated result. In this case, proportionally less data is retrieved from the disk.
Running an aggregation for a limited number of random keys, instead of for all keys. Under certain conditions for key distribution in the data, this provides a reasonably accurate result while using fewer resources.
Adaptive Join Algorithm

ClickHouse adaptively chooses how to JOIN multiple tables, by preferring hash-join algorithm and falling back to the merge-join algorithm if there’s more than one large table.

### Data Replication and Data Integrity Support

ClickHouse uses asynchronous multi-master replication. After being written to any available replica, all the remaining replicas retrieve their copy in the background. The system maintains identical data on different replicas. Recovery after most failures is performed automatically, or semi-automatically in complex cases.

### Role-Based Access Control

ClickHouse implements user account management using SQL queries and allows for role-based access control configuration similar to what can be found in ANSI SQL standard and popular relational database management systems.

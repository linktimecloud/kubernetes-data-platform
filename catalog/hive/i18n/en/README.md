### 1. Introduce

Apache Hive is a distributed, fault-tolerant data warehouse system that enables analytics at a massive scale. 

Hive Metastore(HMS) provides a central repository of metadata that can easily be analyzed to make informed, data driven decisions, and therefore it is a critical component of many data lake architectures. 

Hive is built on top of Apache Hadoop and supports storage on S3, adls, gs etc though hdfs. Hive allows users to read, write, and manage petabytes of data using SQL.

### 2. Key features

#### Hive-Server 2 (HS2)

HS2 supports multi-client concurrency and authentication. It is designed to provide better support for open API clients like JDBC and ODBC.

#### Hive Metastore Server (HMS)

The Hive Metastore (HMS) is a central repository of metadata for Hive tables and partitions in a relational database, and provides clients (including Hive, Impala and Spark) access to this information using the metastore service API. It has become a building block for data lakes that utilize the diverse world of open-source software, such as Apache Spark and Presto. In fact, a whole ecosystem of tools, open-source and otherwise, are built around the Hive Metastore, some of which this diagram illustrates.

#### Hive ACID

Hive provides full acid support for ORC tables out and insert only support to all other formats.

#### Hive Data Compaction

Query-based and MR-based data compactions are supported out-of-the-box.

#### Hive Replication

Hive supports bootstrap and incremental replication for backup and recovery.

#### Security and Observability

Apache Hive supports kerberos auth and integrates with Apache Ranger and Apache Atlas for security and observability.

#### Hive LLAP

Apache Hive enables interactive and subsecond SQL through Low Latency Analytical Processing (LLAP), introduced in Hive 2.0 that makes Hive faster by using persistent query infrastructure and optimized data caching

#### Query planner and Cost based Optimizer

Hive uses Apache Calcite's cost based query optimizer (CBO) and query execution framework to optimize sql queries.

### 3. Application scenarios

Hive is a data warehouse tool based on Hadoop, which can store structured and semi-structured data in Hadoop's distributed file system, and provides a query language similar to SQL, so that users can easily query data, analysis and processing.

#### Data warehouse and ETL

Hive can convert structured and semi-structured data into a format suitable for data warehouses, and can flow data into Hadoop's distributed file system through ETL tools (such as Apache Nifi).

#### Data analysis and report

Hive provides a query language similar to SQL, enabling users to conveniently query, analyze, and process data. At the same time, tools such as Apache Zeppelin can be used for data visualization and report generation.

#### Log analysis

Hive can be used to analyze large-scale log data, such as web server logs, application logs, etc., to understand user behavior, system performance, etc.

#### Machine learning

Hive can be integrated with machine learning tools such as Apache Spark to perform operations such as data preprocessing and feature engineering. At the same time, Hive can also be used as a data warehouse to store and manage data.

#### Recommendation system

Hive can be used in the recommendation system, by storing the user's historical behavior and preferences in Hadoop's distributed file system, and using Hive for data query and analysis to generate personalized recommendation results.


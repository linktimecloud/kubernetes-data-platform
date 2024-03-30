### 1. 介绍

Apache Hive 是可实现大规模分析的分布式容错数据仓库系统。

Hive Metastore (HMS) 提供了一个中央元数据存储库，可以轻松地对其进行分析以做出明智的、数据驱动的决策，因此它是许多数据湖架构的关键组件。 

Hive 构建在 Apache Hadoop 之上，支持通过 hdfs 在 S3、adls、gs 等上进行存储。 Hive 允许用户使用 SQL 读取、写入和管理 PB 级数据。

### 2. 产品能力

#### Hive-Server 2 (HS2)

HS2 支持多客户端并发和认证。 它旨在为 JDBC 和 ODBC 等开放 API 客户端提供更好的支持。

#### Hive Metastore Server (HMS)

Hive Metastore (HMS) 是关系数据库中 Hive 表和分区元数据的中央存储库，并使用 Metastore service API 为客户端（包括 Hive、Impala 和 Spark）提供对此信息的访问。 它已成为利用 Apache Spark 和 Presto 等各种开源软件的数据湖的基石。 事实上，一个完整的工具生态系统，无论是开源工具还是其他工具，都是围绕 Hive Metastore 构建的。

#### Hive ACID

Hive 为 ORC 表提供完整的 acid 支持。

#### Hive Data Compaction（数据压缩）

开箱即用地支持基于查询和MR 的数据压缩。

#### Hive Replication（复制）

Hive Replication是Hive的一个功能，用于将一个Hive表的数据和元数据复制到另一个Hive实例中，从而支持数据的备份、灾难恢复、数据迁移和多数据中心部署等应用场景。

#### 安全性和可观察性

Apache Hive 支持 kerberos 身份验证，并与 Apache Ranger 和 Apache Atlas 集成以实现安全性和可观察性。

#### Hive LLAP

Apache Hive 通过 Hive 2.0 中引入的低延迟分析处理 (LLAP) 启用交互式和亚秒级 SQL，通过使用持久查询基础结构和优化的数据缓存使 Hive 更快

#### 查询计划和基本代价的优化

Hive 使用 Apache Calcite 的基于成本的查询优化器 (CBO) 和查询执行框架来优化 sql 查询。

### 3. 应用场景

Hive是一个基于Hadoop的数据仓库工具，它可以将结构化和半结构化数据存储在Hadoop的分布式文件系统中，并提供了一个类似于SQL的查询语言，使得用户可以方便地进行数据查询、分析和处理。

#### 数据仓库和ETL

Hive可以将结构化和半结构化数据转换成适合于数据仓库的格式，并且可以通过ETL工具（如Apache Nifi）将数据流入到Hadoop的分布式文件系统中。

#### 数据分析和报表

Hive提供了类似于SQL的查询语言，使得用户可以方便地进行数据查询、分析和处理，同时还可以使用Apache Zeppelin等工具来进行数据可视化和报表生成。

#### 日志分析

Hive可以用于分析大规模的日志数据，如Web服务器日志、应用程序日志等，以了解用户的行为、系统性能等。

#### 机器学习

Hive可以与Apache Spark等机器学习工具集成，以进行数据预处理和特征工程等操作，同时还可以使用Hive作为数据仓库来存储和管理数据。

#### 推荐系统

Hive可以用于推荐系统，可以通过将用户的历史行为和偏好存储在Hadoop的分布式文件系统中，并使用Hive进行数据查询和分析，以生成个性化的推荐结果。


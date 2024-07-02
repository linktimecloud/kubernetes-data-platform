### 1. Introduction

Milvus is a cloud-native vector database that features high availability, high performance, and easy scalability, designed for real-time retrieval of massive vector data.

Milvus is built on vector search libraries such as FAISS, Annoy, and HNSW, focusing on solving the problem of dense vector similarity search. Beyond the basic vector search capabilities, Milvus supports data partitioning and sharding, data persistence, incremental data ingestion, scalar-vector hybrid queries, time travel, and other functionalities. It significantly optimizes vector search performance to meet the demands of any vector search application scenario. It is recommended that users deploy Milvus using Kubernetes to achieve optimal availability and elasticity.

Milvus employs a shared storage architecture, with complete separation of storage and computation. The compute nodes support horizontal scaling. Architecturally, Milvus follows the separation of data flow and control flow, divided into four layers: access layer, coordinator service, worker node, and storage. Each layer is independent, allowing for separate scaling and disaster recovery.

### 2. Product Capabilities

#### Millisecond search on trillion vector datasets

Average latency measured in milliseconds on trillion vector datasets.

#### Simplified unstructured data management

-  Rich APIs designed for data science workflows.
-  Consistent user experience across laptop, local cluster, and cloud.
-  Embed real-time search and analytics into virtually any application.

#### Reliable, always on vector database

Milvus’ built-in replication and failover/failback features ensure data and applications can maintain business continuity in the event of a disruption.

#### Highly scalable and elastic

Component-level scalability makes it possible to scale up and down on demand. Milvus can autoscale at a component level according to the load type, making resource scheduling much more efficient.

#### Hybrid search

In addition to vectors, Milvus supports data types such as Boolean, integers, floating-point numbers, and more. A collection in Milvus can hold multiple fields for accommodating different data features or properties. Milvus pairs scalar filtering with powerful vector similarity search to offer a modern, flexible platform for analyzing unstructured data. 

#### Unified Lambda structure

Milvus combines stream and batch processing for data storage to balance timeliness and efficiency. Its unified interface makes vector similarity search a breeze.
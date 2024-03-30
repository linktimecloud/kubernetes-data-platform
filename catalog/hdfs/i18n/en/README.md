### 1. Introduction

HDFS is a Java-based distributed file system with high fault tolerance and scalability, suitable for massive data storage and processing, and is one of the core components of the Apache Hadoop ecosystem.

### 2. Product Capabilities

#### Elastic Scaling

In the host deployment, if you need to expand the HDFS cluster, you need to add more physical servers to support it. In K8s, you can add more K8s nodes to support it, which can better meet the need to dynamically expand and shrink the HDFS cluster.

#### Fault Recovery

In the host deployment, if a physical server fails, it may cause data loss and service interruption. In K8s, you can better handle failure situations through container automatic restart, failure transfer, etc., to ensure the integrity of data and the availability of services.

#### Easy to Manage

In the host deployment, you need to manually install and configure HDFS. In K8s, you can use container images to easily deploy and manage HDFS clusters. At the same time, you can use the Web interface, API and CLI tools provided by K8s to easily monitor, manage and maintain HDFS clusters.

#### High Availability

In the host deployment, a single point of failure may cause the entire HDFS cluster to be unavailable. In K8s, you can deploy HDFS containers to multiple nodes to improve availability, and use the Liveness and Readiness Probe provided by K8s to better detect and handle container failures.

### 3. Application scenarios

#### Big Data Processing

HDFS is usually used to store large data sets, such as web logs, sensor data, and mobile device data. It supports massive data storage and processing with high scalability and reliability.

#### Data Warehouse

HDFS is usually used as a data warehouse to store structured and unstructured data, such as web logs and mobile device data. You can use tools in the Hadoop ecosystem, such as Apache Hive and Apache Flink, to process and query data.


### 1. Introduction

Apache Kafka is a distributed event streaming platform. Based on Kafka, a high-throughput and highly scalable message middleware service can be built. It is suitable for scenarios such as log collection, streaming data processing, and traffic peak shaving and valley removal. The characteristics of scale, high reliability, high concurrent access, and scalability are one of the indispensable components in the big data ecosystem.

### 2. Product Capabilities

#### Out of the box

100% compatible with the open source community Kafka, Allows you to migrate your existing Apache Kafka workloads seamlessly to KDP.

#### Fully managed service

Just focus on the business itself, KDP provides systematic and comprehensive services to help you manage your operational and maintenance challenges.

#### High Performance

High throughput, low latency

### 3. Application scenarios
Kafka is widely used in various systems with high throughput requirements.


#### Log Analysis

Message queue Kafka combined with big data suite can build a complete log analysis system. First, collect logs through the agent deployed on the client, and aggregate the data into the message queue Kafka, and then use big data suites such as Spark to perform multiple calculations and consumption of data, and clean up the original logs, store them on disk or display them on demand .

#### Stream Computing

In the fields of website user behavior, Internet of Things data measurement and control analysis, etc., due to the fast data generation, strong real-time performance, and large amount of data, it is difficult to collect and store them in a unified manner before processing, which makes the traditional data processing architecture unable to meet the needs. . With the emergence of flow computing engines such as Kafka and Spark/Flink, big data message middleware, data can be calculated and analyzed according to business needs, and the results can be saved or distributed to required components.

#### Data transfer hub

During system construction, the same data set needs to be injected into multiple dedicated systems such as HBase, ElasticSearch, Flink/Spark Streaming, and OpenTSDB. Using big data messaging middleware Kafka as a data transfer hub, the same data can be imported into different dedicated systems.
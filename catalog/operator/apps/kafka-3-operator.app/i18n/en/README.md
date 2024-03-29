### 1. Description

Kafka Operator is used to manage Kafka cluster and related components in Kubernetes cluster. It supports Kafka clusters with multiple Kafka versions and different instance configurations. Kafka Operator is implemented based on Kubernetes' Custom Resources and Controller mechanisms, making the deployment and management of Kafka clusters easier and more flexible. In addition, Strimzi Kafka Operator also provides enterprise production-level functional support, such as automatic expansion, automatic backup, monitoring and alerting, etc. These features can help you better manage your Kafka cluster and ensure its availability and reliability.



### 2. Instruction

All the capabilities of the kafka operator have been integrated into KDP. Please use the capabilities provided by the kafka operator directly through the kafka, kafka connect, and schema registry components provided by KDP.
### 1. 应用说明

Kafka Operator用于在Kubernetes集群中管理Kafka及相关组件,支持多个版本和不同实例配置的Kafka集群。Kafka Operator基于Kubernetes的自定义资源（Custom Resources）和控制器（Controller）机制来实现，使得Kafka集群的部署和管理变得更加简单和灵活。此外，Strimzi Kafka Operator还提供企业生产级功能支持，例如自动扩展、自动备份、监控和警报等。这些功能可以帮助您更好地管理Kafka集群，确保其可用性和可靠性。



### 2. 使用说明

kafka operator的所有能力都已集成到KDP中，请通过KDP提供的kafka、kafka connect、schema registry组件直接使用kafka operator提供的能力。
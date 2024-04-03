# Kafka FAQs

## Kafka Connection Issues

Causes and Troubleshooting:

1. Configuration File Issues: Please check if the information in the Kafka configuration file `kafka-cfg.properties` is filled in correctly, and whether the variable informatio is correct when using command-line operations.
2. Access Method Issues: Please confirm whether SASL secure access is enabled and if the matching access method is being used.
3. Access Permission Issues: If the logs show that the topic has not been created or there are authorization information exceptions, please apply for the corresponding resource permissions according to step 2.1 before attempting access again.

## Increased Consumer Lag

Causes and Troubleshooting:

1. Surge in Message Volume: Confirm whether the producer's message volume has increased significantly, leading to a temporary increase in consumer lag. If the production data continues to rise, consider using KDP's resource elasticity capabilities or expand the consumers.
2. Kafka Node Congestion: Check if the resource utilization of the Kafka broker is too high, which may be affected by traffic from other Kafka topics. It is recommended to split the Kafka required for high-traffic businesses.

## Uneven Message Distribution in Partitions

Causes and Troubleshooting:

1. Message Key Specified: Messages are sent to the corresponding partitions based on the key, causing partition message imbalance. This characteristic of the same key falling into the same partition can potentially avoid shuffle operations by the computation engine when used in big data scenarios.
2. Partition Specified: This will result in messages in the specified partition and no messages in the unassigned partitions.
3. Custom Code Implementing Partition Assignment Strategy: Custom strategy logic may lead to uneven message distribution in partitions.

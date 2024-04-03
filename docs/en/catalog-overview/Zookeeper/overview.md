# Zookeeper Overview

ZooKeeper is a distributed, highly available coordination service. It provides distributed configuration services, synchronization services, and naming registry functions.

## Configuration Information

When installing the application, default configurations can be used.

<img src="./images/overview-2024-04-03-09-39-10.png" />

Configurations:

- replicaCount: The number of replicas.
- resources: Resource specifications.
- heapSize: Heap memory size (unit: MiB).
- autopurge
  - snapRetainCount: The number of snapshots to retain.
  - purgeInterval: The cleanup interval in hours. A value of 0 means do not purge.
- chartVersion: The version number of the Helm Chart.
- imageTag: The version of the image.

After successful installation, you can enter the application instance details to perform operations such as updates and uninstallations for operational management.

<img src="./images/overview-2024-04-03-09-39-50.png" />

Prometheus + Grafana are used for collecting key metrics and providing multidimensional monitoring dashboards.

<img src="./images/Overview-2024-03-22-17-54-23.png" />
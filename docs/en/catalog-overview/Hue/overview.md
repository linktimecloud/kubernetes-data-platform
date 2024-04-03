# Hue Overview

Hue (Hadoop User Experience) is an open-source web interface designed for data analysts using the Hadoop ecosystem. It is primarily used for data warehouse components such as Hive, file storage with HDFS, and data processing supported by Spark. Hue provides an easy-to-use interface that allows users to execute queries, browse datasets, and visualize analysis results through Beeswax (Hive's interface).

KDF Hue Component Enhancements

- Unified login/logout
- Logging/Monitoring/Alerting
- Optimized "Hive on Spark" experience

## Architecture

```mermaid
graph TB
    ui[Hue UI] -- HTTP Requests --> server[Hue Server]
    server -- Queries --> hive[(Hive)]
    server -- File Operations --> hdfs[(HDFS)]
    server -- Job Submission --> spark[Spark on Hive]
    
    %% Hue Server interacts with Hue's own database for storing data like user information, job history, etc.
    server -- Meta Data --> db[Hue DB]

    style ui fill:#36f,stroke:#333,stroke-width:2px
    style server fill:#ff6,stroke:#333,stroke-width:2px
    style db fill:#f96,stroke:#333,stroke-width:2px
```

- Hue UI is the user interface through which users can interact with the Hue Server, for example, by submitting queries or managing files. The user interface communicates with the backend Hue Server in the form of HTTP requests.
- Hue Server receives requests from the user interface and communicates with different backend systems based on these requests.
- The Hue Server receives requests from the user interface and communicates with different backend systems based on these requests.
  - It sends SQL queries to Hive, which then executes these queries and returns the results.
  - It performs file operations on HDFS, including uploading, downloading, and managing files.
  - Submitting jobs to Spark on Hive, allowing users to run big data processing tasks on the Spark engine within the Hive context.
- The Hue Server also interacts with Hue DB (MySQL) for storing metadata, such as user information and job history. This provides the necessary persistent storage functionality for the Hue platform, supporting user authentication and operation tracking.

## Component Dependencies

Hue is a web-based application that can be accessed through a browser. The components currently depended on by KDP Hue are:

- HiveServer2 for accessing Hive
- Httpfs for accessing HDFS
- Zookeeper for HA access to HiveServer2
- MySQL for storing Hue's metadata

<img src="./images/Overview-2024-03-25-13-55-34.png" />

## Application Installation

The application can be installed using default configurations.

<img src="./images/overview-2024-04-03-05-48-24.png" />

After installation, the application instance details page allows you to view the application access address and perform operational management operations such as updates and uninstallations.

<img src="./images/overview-2024-04-03-05-49-50.png" />

Log in to the Hue login page using the `root` account without a password.

<img src="./images/Overview-2024-03-25-14-01-44.png" />

After logging in, you can view Hive table data.

<img src="./images/Overview-2024-03-25-14-03-41.png" />

Check HDFS files.

<img src="./images/Overview-2024-03-25-14-04-10.png" />


On the application instance details page, Click "More Operations", you can jump to the Grafana Hue monitoring panel to view monitoring metric information.

<img src="./images/Overview-2024-03-25-13-58-39.png" />

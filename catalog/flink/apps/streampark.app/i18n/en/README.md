### 1. Introduction
StreamPark is a stream processing application integration platform based on Apache Flink, which provides one-stop stream processing application development, deployment, operation and maintenance, monitoring and scheduling capabilities.

KDP integrates StreamPark mainly to facilitate users to submit Flink SQL jobs to Flink session clusters, manage the life cycle of Flink jobs, and monitor the running status of Flink jobs.

### 2. Quick Start

Prerequisites: The `flink-session-cluster` cluster has been installed and is running normally.

#### Login
Access the application homepage and enter the username `admin` and password `streampark` to log in.

#### Configure Flink version
Click `Settings` -  `Flink Home` - `Add New` in the left navigation bar, fill in the following information in the pop-up form, and then click the `OK` button.
- Flink version: `flink-1.17.1`
- Flink Home: `/streampark/flink/flink-1.17.1`

#### Configure Flink cluster
Click `Settings` - `Flink Cluster` - `Add New` in the left navigation bar, fill in the following information in the pop-up form, and then click the `Submit` button.
- Cluster name: `demo`
- Execution mode: `remote`
- Flink version: `flink-1.17.1` (select the Flink version added in the previous step)
- JobManager URL: `http://flink-apache-cluster-session-rest:8081` (Flink session cluster Rest address, you can also use the Ingress address, you need to bring the 80 port)
  
#### Add job

Click `Real-time Development` - `Application` - `Add New` in the left navigation bar, fill in the following information on the new page, and then click the `Submit` button.

- Execution Mode: `remote`
- Flink Version: `flink-1.17.1` (Flink version added in the previous step)
- Flink Cluster: `demo` (Flink cluster added in the previous step)
- Flink SQL:
  
  ```sql
  CREATE TABLE datagen (
    f_sequence INT,
    f_random INT,
    f_random_str STRING,
    ts AS localtimestamp,
    WATERMARK FOR ts AS ts
  ) WITH (
    'connector' = 'datagen',
    -- optional options --
    'rows-per-second'='5',
    'fields.f_sequence.kind'='sequence',
    'fields.f_sequence.start'='1',
    'fields.f_sequence.end'='500',
    'fields.f_random.min'='1',
    'fields.f_random.max'='500',
    'fields.f_random_str.length'='10'
  );

  CREATE TABLE print_table (
    f_sequence INT,
    f_random INT,
    f_random_str STRING
    ) WITH (
    'connector' = 'print'
  );

  INSERT INTO print_table select f_sequence,f_random,f_random_str from datagen;
  ```
  
- Application name: `datagen-print`
After the addition is successful, it will jump to the job management page

#### Run the job
- In the job management page, click the `Release Application` button of the `datagen-print` job, wait for a moment, the publish status becomes `Done` `Success`
- Click the `Start Application` button of the `datagen-print` job, close the `from savepoint` in the pop-up window, click `Apply`, the job will be submitted to the Flink session cluster for running, and the running status will change to `Starting` `Running` `Finished` in turn
  
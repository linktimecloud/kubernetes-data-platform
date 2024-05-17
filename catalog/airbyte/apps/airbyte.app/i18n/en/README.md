### 1. Introduction
Airbyte is an open-source data movement infrastructure for building extract and load (EL) data pipelines. It is designed for versatility, scalability, and ease-of-use.


### 2. Core Concepts
**Source**
A source is an API, file, database, or data warehouse that you want to ingest data from.

**Destination**
A destination is a data warehouse, data lake, database, or an analytics tool where you want to load your ingested data.

**Connector**
An Airbyte component which pulls data from a source or pushes data to a destination.

**Connection**
A connection is an automated data pipeline that replicates data from a source to a destination.

For more details, refer to the official documentation: https://docs.airbyte.com/using-airbyte/core-concepts/


### 2. Quick Start

After installing Airbyte, you can open the Airbyte ingress (like http://airbyte-kdp-data.kdp-e2e.io). Then input any email and organization name. After that, you can create a connection.

#### 2.1 Add a Source

Add a "Faker" source.

Click "Sources", search for "faker" then select "Faker", click "Set up source". 
Airbyte will test the source and show the connection status. (Airbyte will launch a Pod to test the connection that mqy take a few minutes)

For more details, refer to the official documentation: https://docs.airbyte.com/using-airbyte/getting-started/add-a-source

#### 2.2 Add a Destination

Add a "S3" destination. Before adding a destination, you need to create a Minio bucket:
```bash
kubectl exec -it airbyte-minio-0 -n kdp-data  -- bash
mc alias set local http://localhost:9000 minio minio123 
mc mb local/tmp
``` 

Click "Destinations", search for "S3" then select it, input the following fields:

- S3 Key ID: `minio`
- S3 Access Key: `minio123`
- S3 Bucket Name: `tmp`
- S3 Bucket Path: `/`
- S3 Bucket Region: select any region
  
Optional fields:
- S3 Endpoint: `http://airbyte-minio-svc:9000`

Click "Set up destination".

#### 2.3 Create a Connection
Click "Connections", click "Create connection", select the source and destination you just created. 
- Define source: `faker`
- Define destination: `S3`
- Select the stream: click `Next` button
- Conifgure connection: click `Finish & Sync` button

Sync task will be triggered，you can see the sync status in the UI. (It will take a few minutes to download images and to launch pods.)


If sync is successful, you can see the data in the Minio bucket.

```bash
kubectl exec -it airbyte-minio-0 -n kdp-data  -- bash
# list the bucket
mc ls -r local/tmp
# you can delete the bucket if you want
mc rm -r local/tmp
```





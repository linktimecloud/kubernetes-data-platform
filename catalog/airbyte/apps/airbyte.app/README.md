### 1. 简介
Airbyte 是一个开源的数据移动基础设施，用于构建提取和加载（EL）数据管道。它被设计为多功能、可扩展且易于使用。

### 2. 核心概念
**源**
源是一个API、文件、数据库或数据仓库，您希望从中摄取数据。

**目的地**
目的地是一个数据仓库、数据湖、数据库或分析工具，您希望将摄取的数据加载到此处。

**连接器**
连接器是Airbyte的一个组件，用于从源拉取数据或将数据推送到目的地。

**连接**
连接是一个自动化的数据管道，用于将数据从源复制到目的地。

更多详情，请参考官方文档：https://docs.airbyte.com/using-airbyte/core-concepts/

### 2. 快速开始

安装Airbyte后，您可以打开Airbyte入口（例如 http://airbyte-kdp-data.kdp-e2e.io）。然后输入任何电子邮件和组织名称。之后，您可以创建一个连接。

#### 2.1 添加源

添加一个“Faker”源。

点击“Sources”，搜索“faker”然后选择“Faker”，点击“Set up source”。
Airbyte将测试源并显示连接状态。（Airbyte将启动一个Pod来测试连接，这可能需要几分钟时间）

更多详情，请参考官方文档：https://docs.airbyte.com/using-airbyte/getting-started/add-a-source

#### 2.2 添加目的地

添加一个“S3”目的地。在添加目的地之前，您需要创建一个Minio桶：
```bash
kubectl exec -it airbyte-minio-0 -n kdp-data  -- bash
mc alias set local http://localhost:9000 minio minio123 
mc mb local/tmp
```

点击“Destinations”，搜索“S3”然后选择它，输入以下字段：

- S3 Key ID: `minio`
- S3 Access Key: `minio123`
- S3 Bucket Name: `tmp`
- S3 Bucket Path: `/`
- S3 Bucket Region: 选择任何区域

可选字段：

- S3 Endpoint: http://airbyte-minio-svc:9000

点击“Set up destination”。

2.3 创建连接
点击“Connections”，点击“Create connection”，选择您刚刚创建的源和目的地。

- Define source: `faker`
- Define destination: `S3`
- Select the stream: click `Next` button
- Conifgure connection: click `Finish & Sync` button


同步任务将被触发，您可以在UI中看到同步状态。（下载image和启动Pod可能需要几分钟时间。）

如果同步成功，您可以在Minio桶中看到数据。

```bash
kubectl exec -it airbyte-minio-0 -n kdp-data  -- bash
# list the bucket
mc ls -r local/tmp
# you can delete the bucket if you want
mc rm -r local/tmp
```

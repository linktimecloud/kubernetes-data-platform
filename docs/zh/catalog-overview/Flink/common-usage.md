# Flink 组件使用

## 连接方式

- 支持 Flink WebUI 提交作业。
- 支持 Flink 作业管理平台 StreamPark 来提交作业。

下面演示如何通过 Flink WebUI 将 Flink 作业提交到会话集群。

### 获取 Flink 作业 Jar 文件

您可以从[这里](https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.17.1/flink-examples-streaming_2.12-1.17.1-WordCount.jar)下载 Flink 作业 jar 文件，文件名为 `flink-examples-streaming_2.12-1.17.1-WordCount`。

### 将 Flink 作业提交到会话集群

1. 打开 Flink WebUI（（例如Flink WebUI：`http://flink-session-cluster-ingress.yourdomain.com`）
2. 点击 `Submit New Job` -> `Add New`，选择上一步下载的 jar 文件上传, 将 Flink 作业提交到会话集群。

稍后您可以在 Flink WebUI 中看到 Flink 作业正在运行。

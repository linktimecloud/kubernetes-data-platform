# Flink 组件使用

## 连接方式

- 支持 Flink WebUI 提交作业。
- 支持 Flink 作业管理平台 StreamPark 来提交作业。

下面演示如何通过 Flink WebUI 将 Flink 作业提交到会话集群。

### 获取 Flink 作业 Jar 文件

您可以从[这里](https://repo1.maven.org/maven2/org/apache/flink/flink-examples-batch_2.11/1.14.6/flink-examples-batch_2.11-1.14.6-WordCount.jar)下载 Flink 作业 jar 文件，文件名为 `flink-examples-batch_2.11-1.14.6-WordCount.jar`。

或者您可以自己构建 Flink 作业 jar 文件，您可以参考 [Flink WordCount 示例](https://github.com/apache/flink/blob/master/flink-examples/flink-examples-batch/src/main/java/org/apache/flink/examples/java/wordcount/WordCount.java)

### 将 Flink 作业提交到会话集群

打开 Flink WebUI（例如：`http://flink-session-cluster:8081`），将 Flink 作业提交到会话集群。

1. 点击 `Submit New Job` -> `Add New`，选择本地机器上的 jar 文件上传。
2. 点击上传的 jar 文件名称，将 `org.apache.flink.examples.java.wordcount.WordCount` 填写到 `Entry Class` 字段中，将 `--output "/tmp/word-count.txt"` 填写到 `Program Arguments` 字段中，点击 `Submit` 将 Flink 作业提交到会话集群。
  
您可以在 Flink WebUI 中看到 Flink 作业正在运行。

### 1. 应用说明

Spark History Server 是一个用户界面，用于监控已完成的 Spark 应用程序的指标和性能。

### 2. 使用说明

#### 2.1. 使用接入

kdp界面->应用管理->应用市场，找到 "spark-history-server",点击“安装”即可

#### 2.2. 使用实践

kdp界面->系统应用，找到 "spark-history-server" 并点击，点击右上角的 "访问应用"。

通过浏览器，用户可以获取以下信息：
- spark配置信息
- spark job,stage,task的详细信息
- DAG 执行
- driver,executor信息，包含资源利用率
- 执行日志

### 3. 常见问题自检
问题一：web ui看不到spark应用
排查：
1. spark.eventLog.enabled 是否设置为true
2. spark.eventLog.dir和spark.history.fs.logDirectory是否相同
3. spark.eventLog.dir和spark.history.fs.logDirectory设置的路径是否有读写权限

问题二：spark history service中eventLog没有清理
排查：
1. spark.history.fs.cleaner.enabled 是否设置为true
2. spark.history.fs.cleaner.interval 设置检查检查和清查的频率
3. spark.history.fs.cleaner.maxAge eventLog的过期时间


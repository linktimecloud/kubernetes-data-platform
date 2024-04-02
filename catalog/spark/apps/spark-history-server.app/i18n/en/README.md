### 1. Introduce

The Spark History Server is a User Interface that is used to monitor the metrics and performance of the completed Spark applications.

### 2. Instructions

#### 2.1. Deploy

kdp interface -> application management -> application market, find "spark-history-server", click "Install"

#### 2.2. Practice

kdp interface -> system application, find "spark-history-server" and click. Click "Access App" on the top right.

Through the browser, users can obtain the following information:
- Spark configurations used
- Spark Jobs, stages, and tasks details
- DAG execution
- Driver and Executor resource utilization
- Application logs and many more

### 3. FAQS
Q1：The WebUI cannot see the spark application
Check：
1. Whether spark.eventLog.enabled is set to true
2. Are spark.eventLog.dir and spark.history.fs.logDirectory the same?
3. Whether the paths set by spark.eventLog.dir and spark.history.fs.logDirectory have read and write permissions

Q2：The eventLog in the spark history service is not cleared
Check：
1. Whether spark.history.fs.cleaner.enabled is set to true
2. spark.history.fs.cleaner.interval sets the frequency of checking and cleaning
3. The expiration time of spark.history.fs.cleaner.maxAge eventLog


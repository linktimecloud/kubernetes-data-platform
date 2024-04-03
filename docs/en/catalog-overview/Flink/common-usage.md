# Flink Component Usage

## Connection Methods

- Support using Flink WebUI for job submission.
- Support using Flink job management platform StreamPark for submitting jobs.

Below is a demonstration of how to submit a Flink job to a session cluster via Flink WebUI.

### Obtaining the Flink Job Jar File

You can download the Flink job jar file from[here](https://repo1.maven.org/maven2/org/apache/flink/flink-examples-batch_2.11/1.14.6/flink-examples-batch_2.11-1.14.6-WordCount.jar)，The file name is `flink-examples-batch_2.11-1.14.6-WordCount.jar`.

Or you can build your own Flink job jar file. Refer to the [Flink WordCount example](https://github.com/apache/flink/blob/master/flink-examples/flink-examples-batch/src/main/java/org/apache/flink/examples/java/wordcount/WordCount.java)

### Submitting the Flink Job to the Session Cluster

Open the Flink WebUI（for example:`http://flink-session-cluster:8081`）and submit the Flink job to the session cluster.

1. Click `Submit New Job` -> `Add New`,select the jar file on your local machine to upload.
2. Click on the uploaded jar file name, enter `org.apache.flink.examples.java.wordcount.WordCount` in `the Entry Class` field, and enter `--output "/tmp/word-count.txt"` in the Program Arguments field. Click `Submit` to submit the Flink job to the session cluster.
  
You can check the Flink job running in the Flink WebUI.

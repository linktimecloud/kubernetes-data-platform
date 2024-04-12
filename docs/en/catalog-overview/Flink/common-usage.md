# Flink Component Usage

## Connection Methods

- Support using Flink WebUI for job submission.
- Support using Flink job management platform StreamPark for submitting jobs.

Below is a demonstration of how to submit a Flink job to a session cluster via Flink WebUI.

### Obtaining the Flink Job Jar File

You can download the Flink job jar file from [here](https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.17.1/flink-examples-streaming_2.12-1.17.1-WordCount.jar), with the file name `flink-examples-streaming_2.12-1.17.1-WordCount`.

### Submitting the Flink Job to the Session Cluster

1. Open Flink WebUI (for example, Flink WebUI: `http://flink-session-cluster-ingress.yourdomain.com`)
2. Click `Submit New Job` -> `Add New`, select the jar file downloaded in the previous step, and submit the Flink job to the session cluster.

Later, you can see the Flink job running in the Flink WebUI.

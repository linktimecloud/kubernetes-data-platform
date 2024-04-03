# Flink Developer Guide

This document mainly introduces how to develop Flink applications using the `Flink DataStream API` and `Flink SQL`. For more information, please refer to the [Flink API](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/concepts/overview/#flinks-apis). It also explains how to use the Flink job management platform, StreamPark, to submit and run Flink applications.

Prerequisites:

- Ensure that the Flink Operator, Flink session cluster, and Flink job management platform StreamPark have been deployed on KDP.
- Complete the quick start guide according to the Flink documentation to ensure the Flink cluster is running properly.
- Configure the relevant parameters of the Flink job management platform according to the StreamPark documentation, and ensure the demo job runs successfully.

## Flink DataStream API Application Development

The `Flink DataStream API` is an advanced API used for processing unbounded data streams. It provides numerous operators that can be used to manipulate data streams. For example, `map`, `filter`, `keyBy`, `reduce`, `window`, etc. Below is a simple example demonstrating how to develop a basic WordCount application using the `Flink DataStream API`.

### Program Development

```java

package org.apache.flink.streaming.examples.socket;

import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;

/**
 * Implements a streaming windowed version of the "WordCount" program.
 *
 * <p>This program connects to a server socket and reads strings from the socket. The easiest way to
 * try this out is to open a text server (at port 12345) using the <i>netcat</i> tool via
 *
 * <pre>
 * nc -l 12345 on Linux or nc -l -p 12345 on Windows
 * </pre>
 *
 * <p>and run this example with the hostname and the port as arguments.
 */
public class SocketWindowWordCount {

    public static void main(String[] args) throws Exception {

        // the host and the port to connect to
        final String hostname;
        final int port;
        try {
            final ParameterTool params = ParameterTool.fromArgs(args);
            hostname = params.has("hostname") ? params.get("hostname") : "localhost";
            port = params.getInt("port");
        } catch (Exception e) {
            System.err.println(
                    "No port specified. Please run 'SocketWindowWordCount "
                            + "--hostname <hostname> --port <port>', where hostname (localhost by default) "
                            + "and port is the address of the text server");
            System.err.println(
                    "To start a simple text server, run 'netcat -l <port>' and "
                            + "type the input text into the command line");
            return;
        }

        // get the execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // get input data by connecting to the socket
        DataStream<String> text = env.socketTextStream(hostname, port, "\n");

        // parse the data, group it, window it, and aggregate the counts
        DataStream<WordWithCount> windowCounts =
                text.flatMap(
                                (FlatMapFunction<String, WordWithCount>)
                                        (value, out) -> {
                                            for (String word : value.split("\\s")) {
                                                out.collect(new WordWithCount(word, 1L));
                                            }
                                        },
                                Types.POJO(WordWithCount.class))
                        .keyBy(value -> value.word)
                        .window(TumblingProcessingTimeWindows.of(Time.seconds(5)))
                        .reduce((a, b) -> new WordWithCount(a.word, a.count + b.count))
                        .returns(WordWithCount.class);

        // print the results with a single thread, rather than in parallel
        windowCounts.print().setParallelism(1);

        env.execute("Socket Window WordCount");
    }

    // ------------------------------------------------------------------------

    /** Data type for words with count. */
    public static class WordWithCount {

        public String word;
        public long count;

        @SuppressWarnings("unused")
        public WordWithCount() {}

        public WordWithCount(String word, long count) {
            this.word = word;
            this.count = count;
        }

        @Override
        public String toString() {
            return word + " : " + count;
        }
    }
}
```

This code is a simple Apache Flink program that performs a windowed word count task by reading data from a socket. Here is an explanation of the main parts of the code:

1. Obtaining the execution environment:
    - Use StreamExecutionEnvironment.getExecutionEnvironment() to obtain the stream processing execution environment.
2. Obtaining input data:
    - Connect to the specified host and port using env.socketTextStream(hostname, port, "\n") to read text data streams from the socket.
3. Data stream transformation:
    - Use flatMap to split each line of text data into words and convert them into (word, count) tuple form, with count initialized to 1.
    - Use keyBy to group by word.
    - Specify the window type as a Processing Time window of 5 seconds using window.
4. Aggregation computation:
    - Use reduce to aggregate data within the window, summing up counts for the same words.
5. Result output:
    - Use print to print the windowed computation results to the console.
6. Executing the job:
    - Call env.execute("Socket Window WordCount") to submit the job for execution.

The main function of this program is to read text data streams from a specified socket, perform real-time word counting within the window, and print the results to the console.

Source code address: <https://github.com/apache/flink/tree/release-1.17/flink-examples/flink-examples-streaming>

Program package download address: <https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.17.1/flink-examples-streaming_2.12-1.17.1-SocketWindowWordCount.jar>

### Submitting Applications to the Flink Cluster

Two methods are introduced for submitting applications: one is through the Flink CLI, and the other is through the Flink job management platform StreamPark.

#### Submitting Applications via Flink CLI

Enter the flink session cluster container and execute the following command:

```shell
./bin/flink run -d ./examples/streaming/SocketWindowWordCount.jar --hostname `(grep 'flink-session-cluster' /etc/hosts | head -n 1 | awk '{print $1}')` --port 9999 && nc -l 9999
```

After successfully publishing the job, input text data and observe the output results on the flink session cluster console.

Clean up job:
Exit the nc interactive interface and execute the following command:

```shell
./bin/flink list
## expecte output:job id
./bin/flink cancel <job_id>
```

#### Logging in to StreamPark WebUI to Submit

**Preparation**

Enter the flink session cluster container to view the IP address, and execute the following command:

```shell
grep 'flink-session-cluster' /etc/hosts | head -n 1 | awk '{print $1}'
## Record the output Flink container IP address (e.g., 10.233.114.142)，as the StreamPark job parameters will use it.

## Start the socket service:
nc -l 9999
## After successfully publishing the job, input text data and observe the output results on the flink session cluster console.

```

**Logging in to StreamPark WebUI to Submit**


Log in to the StreamPark WebUI, click on `real-time development` - `job management` - `add` in the left navigation bar, fill in the information as follows on the new page, and then click `submit`.

- Job mode: `Custom Code`
- Execution mode: `remote`
- Resource source:  `upload local job`
- Flink version: `flink-1.17.1`
- Flink cluster:  `demo`
- Program Jar: Select the jar package built above or the downloaded jar package
- Program Main: `org.apache.flink.streaming.examples.socket.SocketWindowWordCount`
- Job name: `Socket Window WordCount`
- Program parameters: `--port 9999 --hostname 10.233.114.142` (IP address to be filled in according to the actual situation)

After successful addition, you will be redirected to the job management page.

**Running the job**

- On the job management page, click the `publish job` button for the `datagen-print` job, and the publish status will change to `Done` `Success`
- Click the `start job` button for the `datagen-print` job, close the `from savepoint` in the pop-up window, click `apply`, the job will be submitted to the Flink session cluster for running, and the running status will change to `Starting`, `Running`, `Finished` in turn.
- Finally, use the `stop job` button to stop the job.

## Flink SQL Application Development

`Flink SQL` is a high-level API for processing unbounded and bounded data streams. It provides a SQL-like query language that can be used to process data streams. Here is a simple example showing how to use `Flink SQL` to develop a simple application. It simulates generating order data and calculates the total amount for each user, then prints the results.

### Program Development


```java
Flink SQL is as follows:

```sql
create table UserOrder(
  user_id int,
  money_amount int,
  ts AS localtimestamp,
  WATERMARK FOR ts AS ts
) with (
  'connector' = 'datagen',
  'rows-per-second' = '1',
  'fields.user_id.min' = '1',
  'fields.user_id.max' = '10',
  'fields.money_amount.min' = '1',
  'fields.money_amount.max' = '100'
);

create table UserMoneyAmount (
  user_id int,
  total_amount int,
  primary key (user_id) not enforced
) with ('connector' = 'print');

insert into
  UserMoneyAmount
select
  user_id,
  sum(money_amount) as total_amount
from
  UserOrder
group by
  user_id;

```

- UserOrder table creation:
The UserOrder table is used to store user order data, including user ID (user_id), order amount (money_amount), and order timestamp (ts). The timestamp column ts is generated by the built-in function localtimestamp and watermark is defined through WATERMARK to handle event time semantics.
- UserMoneyAmount table creation:
The UserMoneyAmount table is used to store the total amount for each user, containing two columns: user ID (user_id) and total amount (total_amount). Since it is a table for printing output, no primary key is defined.
- Data insertion operation:
Use the INSERT INTO statement to select data from the UserOrder table, group by user_id, then calculate the total amount for each user (using the SUM function), and insert the results into the UserMoneyAmount table.

### Submitting Applications to the Flink Cluster

Two methods are introduced for submitting applications: one is through the Flink CLI, and the other is through the Flink job management platform StreamPark.

#### Submitting Applications via Flink CLI

Enter the flink session cluster container and execute the following command:

```shell
## Start sql-client
./bin/sql-client.sh 
## In the Flink SQL interactive terminal, enter the three SQL statements above, one at a time, and press Enter after each; multiple statements cannot be executed simultaneously.

## Expected successful execution of the three statements, job submitted successfully, and job id output, record the id for later use to cancel the job.

## Access Flink WebUI to check the job status

## Return to the Flink SQL interactive terminal to cancel the job
./bin/flink cancel <job_id>

```

#### Submitting Applications via Flink Job Management

Click on `real-time development` - `job management` - `add` in the left navigation bar, fill in the information as follows on the new page, and then click `submit`.

- Execution mode: `remote`
- Flink version: `flink-1.17.1`
- Flink cluster: `demo`
- Flink SQL:
  
```sql
create table UserOrder(
  user_id int,
  money_amount int,
  ts AS localtimestamp,
  WATERMARK FOR ts AS ts
) with (
  'connector' = 'datagen',
  'rows-per-second' = '1',
  'fields.user_id.min' = '1',
  'fields.user_id.max' = '10',
  'fields.money_amount.min' = '1',
  'fields.money_amount.max' = '100'
);

create table UserMoneyAmount (
  user_id int,
  total_amount int,
  primary key (user_id) not enforced
) with ('connector' = 'print');

insert into
  UserMoneyAmount
select
  user_id,
  sum(money_amount) as total_amount
from
  UserOrder
group by
  user_id;
  
```
  
- Job name: `user-order-total-amount`
  
After successful addition, you will be redirected to the job management page.

Running the job

- On the job management page, click the `publish job` button for the job, and the publish status will change to `Done` `Success`.
- Click the `start job` button for the job, close the from savepoint in the pop-up window, click `apply`, the job will be submitted to the Flink session cluster for running, and the running status will change to `Starting`, `Running`, `Finished` in turn.
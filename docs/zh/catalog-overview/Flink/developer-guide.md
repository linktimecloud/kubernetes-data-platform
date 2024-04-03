# Flink 开发指南

本文主要介绍一一下如何使用`Flink DataStream API`和`Flink SQL`开发Flink应用程序。更多请参考[Flink API 介绍](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/concepts/overview/#flinks-apis)。同时，将介绍如何使用 Flink 作业管理平台提交和运行 Flink 应用程序。

前置条件：

- 确保已经在KDP上部署了Flink Operator, Flink session cluster和Flink作业管理平台Streampark。
- 根据Flink文档完成快速开始指南，确保Flink集群正常运行。
- 根据Streampark的文档，配置了Flink作业管理平台的相关参数, demo 作业运行成功

## Flink DataStream API 应用开发

`Flink DataStream API`是一种用于处理无界数据流的高级API。它提供了许多操作符，可以用于处理数据流。例如，`map`、`filter`、`keyBy`、`reduce`、`window`等。下面是一个简单的示例，展示如何使用`Flink DataStream API`开发一个简单的`WordCount`应用程序。

### 程序开发

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

这段代码是一个简单的Apache Flink程序，执行从socket读取数据的窗口化单词计数任务。下面是对代码的主要部分进行解释：

1. 获取执行环境：
    - 使用StreamExecutionEnvironment.getExecutionEnvironment()获取流处理执行环境。
2. 获取输入数据：
    - 使用env.socketTextStream(hostname, port, "\n")连接到指定的主机名和端口，从socket中读取文本数据流。
3. 数据流转换：
    - 使用flatMap操作将每行文本数据拆分为单词，并转换为(word, count)的元组形式，其中count初始化为1。
    - 使用keyBy按单词进行分组。
    - 使用window指定窗口类型为Processing Time窗口，大小为5秒。
4. 聚合计算：
    - 使用reduce对窗口内的数据进行聚合计算，将相同单词的计数进行累加。
5. 结果输出：
    - 使用print将窗口化计算结果打印到控制台。
6. 执行作业：
    - 调用env.execute("Socket Window WordCount")提交作业执行。

这个程序的主要功能是从指定的socket读取文本数据流，对窗口内的单词进行实时计数，并将结果打印到控制台。

源代码地址：<https://github.com/apache/flink/tree/release-1.17/flink-examples/flink-examples-streaming>

程序构建的jar包下载地址：<https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.17.1/flink-examples-streaming_2.12-1.17.1-SocketWindowWordCount.jar>

### 提交应用程序到 Flink 集群

介绍二种方式，一种是通过Flink CLI提交应用程序，另一种是通过Flink作业管理平台Streampark提交应用程序。

#### 通过 Flink CLI 提交应用程序

进入 flink session cluster 容器，执行以下命令：

```shell
./bin/flink run -d ./examples/streaming/SocketWindowWordCount.jar --hostname `(grep 'flink-session-cluster' /etc/hosts | head -n 1 | awk '{print $1}')` --port 9999 && nc -l 9999
```

执行成功后，进入nc命令行，输入文本数据, 然后回车; 输入多条文本数据，查看flink session cluster控制台输出结果。
也可以到flink WebUI 查看作业状态。

清理作业：
退出nc交互界面，执行以下命令：

```shell
./bin/flink list
## 预期会输出job id
./bin/flink cancel <job_id>
```

#### 通过 Flink 作业管理平台 Streampark 提交应用程序

**准备**

进入 flink session cluster 容器查看ip地址，执行以下命令：

```shell
grep 'flink-session-cluster' /etc/hosts | head -n 1 | awk '{print $1}'
## 记录输出的flink容器ip地址(如：10.233.114.142)，streampark 作业参数会用到

## 起socket服务
nc -l 9999
## 在成功发布作业后，输入文本数据，查看flink session cluster控制台输出结果

```

**登录 Streampark WebUI 提交**

登录 Streampark WebUI ，在左侧导航栏点击`实时开发` - `作业管理` - `添加`，在新的页面中按照如下信息填写，然后点击`提交`按钮。

- 作业模式：`Custom Code`
- 执行模式: `remote`
- 资源来源: `upload local job`
- Flink版本: `flink-1.17.1`
- Flink集群: `demo`
- Program Jar: 选择上面构建的jar包或者下载的jar包
- Program Main: `org.apache.flink.streaming.examples.socket.SocketWindowWordCount`
- 作业名称: `Socket Window WordCount`
- 程序参数: `--port 9999 --hostname 10.233.114.142` （ip 地址根据实际情况填写）

添加成功后会跳转到作业管理页面

**运行作业**

- 在作业管理页面，点击`datagen-print`作业的`发布作业`按钮，稍等片刻，发布状态变为`Done` `Success`
- 点击`datagen-print`作业的`启动作业`按钮，关闭弹窗中的`from savepoin`, 点击`应用`, 作业将提交到Flink session集群运行, 运行状态依次变为`Starting` `Running` `Finished`
- 最后不需要运行时，作业的`停止作业`按钮，停止作业。

## Flink SQL 应用开发

`Flink SQL`是一种用于处理无界和有界数据流的高级API。它提供了类似于SQL的查询语言，可以用于处理数据流。下面是一个简单的示例，展示如何使用`Flink SQL`,开发一个简单应用程序。用于模拟生成订单数据，并计算每个用户的总金额，然后将结果打印输出。

### 程序开发

```java
Flink SQL 如下：

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

- UserOrder表创建：
UserOrder表用于存储用户订单数据，包括用户ID（user_id）、订单金额（money_amount）和订单时间戳（ts）。
时间戳列ts通过内置函数localtimestamp生成，并通过WATERMARK定义了水印，用于处理事件时间语义。
- UserMoneyAmount表创建：
UserMoneyAmount表用于存储每个用户的总金额，包含用户ID（user_id）和总金额（total_amount）两列。
由于是用于打印输出的表，因此没有定义主键。
- 数据插入操作：
使用insert into语句从UserOrder表中选择数据，并按照user_id进行分组，然后计算每个用户的总金额（使用sum函数），将结果插入到UserMoneyAmount表中。

### 提交应用程序到Flink集群

介绍二种方式，一种是通过Flink CLI提交应用程序，另一种是通过Flink作业管理平台Streampark提交应用程序。

#### 通过Flink CLI提交应用程序

进入 flink session cluster 容器，执行以下命令：

```shell
## 启动sql-client
./bin/sql-client.sh 
## 在flink sql交互终端中输入上面的三条sql语句， 需要单条执行，然后回车，不支持多条语句同时执行

## 预期三条语句执行成功，job 提交成功并输出 job id, 记录id稍后用于取消作业

## 访问Flink WebUI 查看作业状态

## 返回flink sql 交互终端，取消作业
./bin/flink cancel <job_id>

```

#### 通过 Flink 作业管理平台 Streampark 提交应用程序

在左侧导航栏点击`实时开发` - `作业管理` - `添加`，在新的页面中按照如下信息填写，然后点击`提交`按钮。

- 执行模式: `remote`
- Flink版本: `flink-1.17.1`
- Flink集群: `demo`
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
  
- 作业名称: `user-order-total-amount`
  
添加成功后会跳转到作业管理页面

运行作业

- 在作业管理页面，点击该作业的`发布作业`按钮，稍等片刻，发布状态变为`Done` `Success`
- 点击该作业的`启动作业`按钮，关闭弹窗中的`from savepoin`, 点击`应用`, 作业将提交到Flink session集群运行, 运行状态依次变为`Starting` `Running` `Finished`

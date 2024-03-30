### 1. 介绍
StreamPark 是一个基于 Apache Flink 的流处理应用程序集成平台，提供了一站式的流处理应用程序开发、部署、运维、监控和调度能力。
KDP 集成 StreamPark 主要用于方便用户提交 Flink SQL 作业到 Flink session 集群，管理 Flink 作业的生命周期，以及监控 Flink 作业的运行状态。

### 2. 快速开始

前提： `flink-session-cluster` 集群已经安装且正常运行。

#### 登录
访问应用首页，输入用户名`admin`和密码`streampark`登录。

#### 配置Flink版本
在左侧导航栏点击`设置中心` - `Flink版本` - `添加`，在弹出的表单中按照如下信息填写，然后点击`确定`按钮。
- Flink名称：`flink-1.17.1`
- 安装路径：`/streampark/flink/flink-1.17.1`

#### 配置Flink集群
在左侧导航栏点击`设置中心` - `Flink集群` - `添加`，在弹出的表单中按照如下信息填写，然后点击`提交`按钮。
- 集群名称:`demo`
- 执行模式: `remote`
- Flink版本: `flink-1.17.1` (选择上一步添加的Flink版本)
- JobManager URL: `http://flink-session-cluster-rest:8081` (Flink session集群的Rest地址, 也可以使用Ingress地址需要带上80端口)


#### 添加作业

在左侧导航栏点击`实时开发` - `作业管理` - `添加`，在新的页面中按照如下信息填写，然后点击`提交`按钮。

- 执行模式: `remote`
- Flink版本: `flink-1.17.1` (上面步骤添加的Flink版本)
- Flink集群: `demo` (上面步骤添加的Flink集群)
- Flink SQL:
  
  ```sql
  CREATE TABLE datagen (
    f_sequence INT,
    f_random INT,
    f_random_str STRING,
    ts AS localtimestamp,
    WATERMARK FOR ts AS ts
  ) WITH (
    'connector' = 'datagen',
    -- optional options --
    'rows-per-second'='5',
    'fields.f_sequence.kind'='sequence',
    'fields.f_sequence.start'='1',
    'fields.f_sequence.end'='500',
    'fields.f_random.min'='1',
    'fields.f_random.max'='500',
    'fields.f_random_str.length'='10'
  );

  CREATE TABLE print_table (
    f_sequence INT,
    f_random INT,
    f_random_str STRING
    ) WITH (
    'connector' = 'print'
  );

  INSERT INTO print_table select f_sequence,f_random,f_random_str from datagen;
  ```
  
- 作业名称: `datagen-print`
  
添加成功后会跳转到作业管理页面

#### 运行作业
- 在作业管理页面，点击`datagen-print`作业的`发布作业`按钮，稍等片刻，发布状态变为`Done` `Success`
- 点击`datagen-print`作业的`启动作业`按钮，关闭弹窗中的`from savepoin`, 点击`应用`, 作业将提交到Flink session集群运行, 运行状态依次变为`Starting` `Running` `Finished`
  


  
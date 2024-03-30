### 1. 应用说明

HDFS是一个基于Java的分布式文件系统，具有高容错性和可扩展性，适用于海量数据存储和处理，是Apache Hadoop生态系统的核心组件之一。

### 2. 快速入门

#### 2.1 部署创建
HDFS 由系统管理员创建发布，用户可直接使用。

#### 2.2 使用实践

##### 2.2.1 进入 hdfs 容器

hdfs pod 有以下三种：

- hdfs-namenode-x
- hdfs-journalnode-x
- hdfs-datanode-x

上面的 `x` 代表序号，从 0 开始。

以进入 `hdfs-namenode-0` 为例，执行

```shell
kubectl exec -it hdfs-namenode-0 -n kdp-data -c hdfs-namenode -- bash
```

然后可以执行 `hdfs` 命令
   
##### 2.2.2 命令行方式访问

```shell
# 查看目录
hdfs dfs -ls /
# 创建目录
hdfs dfs -mkdir /test
# 上传文件
hdfs dfs -put /etc/hosts /test
# 查看文件
hdfs dfs -cat /test/hosts
```

#### 2.2.3 代码方式访问（java）

1. maven 依赖

```xml
<dependency>
  <groupId>org.apache.hadoop</groupId>
  <artifactId>hadoop-common</artifactId>
  <version>3.1.1</version>
</dependency>
<dependency>
  <groupId>org.apache.hadoop</groupId>
  <artifactId>hadoop-client</artifactId>
  <version>3.1.1</version>
</dependency>
```

2. 代码示例

```java
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;

import java.net.URI;

public class HdfsClient {

    public static void main(String[] args) throws Exception {
        //hdfsPath、hdfsUser 需根据实际值进行修改
        String hdfsPath = "hdfs://default:8020";
        String hdfsUser = "hadoop";

        Configuration configuration = new Configuration();
        FileSystem fs = FileSystem.get(new URI(hdfsPath), configuration, hdfsUser);

        Path rootPath = new Path("/");
        FileStatus[] status = fs.listStatus(rootPath);
        for (FileStatus fileStatus : status) {
            System.out.println(fileStatus.getPath().getName());
        }
        fs.close();
    }
}
```

### 3. 常见问题自检

#### 3.1. Java 客户端访问报错

原因与排查：

1. 如果HDFS配置了HA，检查HDFS NameNode地址是否是Active的那个；
2. 检查pom中是否存在Hadoop相关的包冲突。

### 4. 附录

#### 4.1. 概念介绍

**NameNode**

NameNode负责管理文件系统的命名空间，管理文件的元数据，如文件名、文件属性、文件目录等。

**DataNode**

DataNode负责存储文件的数据块，负责处理客户端的读写请求。

**JournalNode**

JournalNode负责存储NameNode的编辑日志，保证NameNode的高可用。


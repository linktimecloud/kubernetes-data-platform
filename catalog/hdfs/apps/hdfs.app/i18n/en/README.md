### 1. Application Description

HDFS is a Java-based distributed file system with high fault tolerance and scalability, suitable for massive data storage and processing, and is one of the core components of the Apache Hadoop ecosystem.

### 2. Quick Start

#### 2.1 Deploy

HDFS is created and released by system administrators, and users can use it directly.

#### 2.2. Practice

##### 2.2.1 Enter the hdfs container

There are three types of hdfs pods:

- hdfs-namenode-x
- hdfs-journalnode-x
- hdfs-datanode-x

The x above represents a sequential number starting from 0.

For example, to enter hdfs-namenode-0 in the default namespace, run

```shell
kubectl exec -it hdfs-namenode-0 -n default -- bash
```

Then you can execute the hdfs command

#### 2.2.2 Command line access

```shell
# View the root directory
hdfs dfs -ls /
# Create a directory
hdfs dfs -mkdir /test
# Upload a file
hdfs dfs -put /etc/hosts /test
# View the file
hdfs dfs -cat /test/hosts
```
  
#### 2.2.3 Code access(java)

1. Add the following dependencies in pom.xml.
   
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
 
2. Code demo

```java
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.security.UserGroupInformation;

import java.net.URI;

public class HdfsClient {

    public static void main(String[] args) throws Exception {
        //hdfsPath、hdfsUser needs to be modified according to the actual value 
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

### 3. FAQ

#### 3.1. Java client access error

Reasons and results:

1. If HDFS is configured with HA, check whether the HDFS NameNode address is the Active one;
2. Check whether there is any Hadoop-related package conflict in the pom.

### 4. Appendix

#### 4.1. Concept

**NameNode**

NameNode is responsible for managing the namespace of the file system and managing file metadata, such as file names, file attributes, and file directories.

**DataNode**

The DataNode is responsible for storing the data blocks of the file and processing the client's read and write requests.

**JournalNode**

JournalNode is responsible for storing the edit log of NameNode to ensure the high availability of NameNode.




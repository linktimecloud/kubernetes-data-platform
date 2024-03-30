### 1. 应用说明

Hive Metastore(HMS)是一个元数据存储系统，用于管理Hive表、分区、列等的元数据信息，包括表的名称、结构、存储位置、数据格式等。Hive Metastore可以将这些元数据信息存储在多种不同的后端数据库中，如MySQL、Oracle、PostgreSQL等，Hive Metastore可独立部署。

### 2. 快速入门

#### 2.1. 部署创建

Hive Metastore是系统应用，是全局唯一的，如果需要部署请联系系统管理员

#### 2.2. 使用实践

##### 2.2.1. HSQL

HMS服务部署完成后，通过 `kubectl` 命令进入到HMS容器，然后执行 `hive` 命令。

```shell
cd /opt/hive/bin
./hive
```

通过以下命令，可以执行元数据相关操作

###### 创建新表

```sql
CREATE TABLE mytable (
  id INT,
  name STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ',';
```

###### 查看表的元数据

此命令将显示表的创建语句以及其所有的元数据信息，包括表的名称、结构、存储位置、数据格式等。

```sql
SHOW CREATE TABLE mytable;
```

##### 2.2.2. java

pom.xml

```xml
<dependency>
    <groupId>org.apache.hive</groupId>
    <artifactId>hive-metastore</artifactId>
    <version>3.1.3</version>
</dependency>
```

> HMS_THRIFT_URL 替换为hms的thrift地址

```java
package com.wdlily.hive;

import lombok.extern.slf4j.Slf4j;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hive.conf.HiveConf;
import org.apache.hadoop.hive.metastore.IMetaStoreClient;
import org.apache.hadoop.hive.metastore.RetryingMetaStoreClient;
import org.apache.hadoop.hive.metastore.api.MetaException;

@Slf4j
public class HMSClient {

    private static final String HMS_THRIFT_URL = "thrift://hive-metastore-svc.admin.svc.cluster.local:9083";

    public static void main(String[] args) throws Exception {

        HiveConf conf = new HiveConf();
        conf.getAllProperties();
        conf.set(HiveConf.ConfVars.METASTOREURIS.varname, HMS_THRIFT_URL);

        IMetaStoreClient client = init(conf);

        System.out.println("===========dbs=============");
        client.getAllDatabases().forEach(System.out::println);

        System.out.println("==========tables==============");
        client.getAllTables("metrics").forEach(System.out::println);

    }

    private static IMetaStoreClient init(HiveConf conf) throws MetaException {
        try {
            return RetryingMetaStoreClient.getProxy(conf, false);
        } catch (MetaException e) {
            throw e;
        }
    }

}

```

### 3. 常见问题自检
问题一：HMS无法启动

排查：
1. 检查HMS的配置文件(hive-site.xml)和数据库连接信息，保证数据库已正确安装和配置
2. 查看日志，kdp 界面->核心组件->hive->hive-metastore->查看日志

问题二：创建表失败

排查：
1. 查看用户是否有相关权限

问题三：Hive表元数据丢失

排查：
1. 检查元数据存储后端数据库是否正常
2. 数据库中是否存在表的元数据信息，是否有备份





